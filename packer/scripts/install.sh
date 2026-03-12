#!/bin/bash
# Packer provisioner script — runs inside the AMI build instance.
# Installs Apache, PHP, EFS utilities, WP-CLI, and sets up systemd
# so that httpd always waits for the EFS mount before starting.
set -euo pipefail

echo "==> Waiting for cloud-init to finish"
cloud-init status --wait || true

echo "==> Updating system packages"
dnf update -y

echo "==> Installing Apache and PHP 8 extensions"
dnf install -y \
  httpd \
  php \
  php-mysqlnd \
  php-gd \
  php-mbstring \
  php-xml \
  php-intl \
  php-zip \
  php-opcache \
  mod_ssl

echo "==> Installing EFS utilities and supporting tools"
dnf install -y \
  amazon-efs-utils \
  nfs-utils \
  amazon-ssm-agent \
  jq \
  unzip

echo "==> Installing WP-CLI"
curl -sL "https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar" \
  -o /usr/local/bin/wp
chmod +x /usr/local/bin/wp
wp --info --allow-root

echo "==> Installing CloudWatch agent"
dnf install -y amazon-cloudwatch-agent

echo "==> Configuring CloudWatch agent"
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access.log",
            "log_group_name": "/lodge104/httpd/access",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%d/%b/%Y:%H:%M:%S %z"
          },
          {
            "file_path": "/var/log/httpd/error.log",
            "log_group_name": "/lodge104/httpd/error",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/lodge104/ec2/user-data",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/", "/var/www/html"]
      }
    },
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}"
    }
  }
}
EOF

echo "==> Configuring Apache vhost for WordPress"
cat > /etc/httpd/conf.d/wordpress.conf << 'EOF'
<VirtualHost *:80>
    ServerName lodge104.net
    ServerAlias www.lodge104.net
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Pass the real client IP from CloudFront/ALB
    RemoteIPHeader X-Forwarded-For

    ErrorLog  /var/log/httpd/error.log
    CustomLog /var/log/httpd/access.log combined
</VirtualHost>
EOF

echo "==> Enabling mod_rewrite and mod_remoteip"
cat > /etc/httpd/conf.modules.d/00-remoteip.conf << 'EOF'
LoadModule remoteip_module modules/mod_remoteip.so
EOF

echo "==> Creating EFS mount point"
mkdir -p /var/www/html
chown apache:apache /var/www/html

echo "==> Creating EFS mount systemd service"
# User-data will write /etc/lodge104/efs-id at first boot.
# This service reads that file and mounts EFS before httpd starts.
mkdir -p /usr/local/lib/lodge104

cat > /usr/local/bin/mount-efs.sh << 'SCRIPT'
#!/bin/bash
set -euo pipefail

EFS_ID_FILE="/etc/lodge104/efs-id"
MOUNT_POINT="/var/www/html"

if [ ! -f "$EFS_ID_FILE" ]; then
  echo "ERROR: $EFS_ID_FILE not found — run user-data first" >&2
  exit 1
fi

EFS_ID=$(cat "$EFS_ID_FILE")

if mountpoint -q "$MOUNT_POINT"; then
  echo "EFS already mounted at $MOUNT_POINT"
  exit 0
fi

echo "Mounting EFS $EFS_ID at $MOUNT_POINT"
mkdir -p "$MOUNT_POINT"
mount -t efs -o tls,iam "${EFS_ID}":/ "$MOUNT_POINT"
echo "EFS mounted successfully"
SCRIPT
chmod +x /usr/local/bin/mount-efs.sh

cat > /etc/systemd/system/mount-efs.service << 'EOF'
[Unit]
Description=Mount EFS volume for WordPress
After=network-online.target
Wants=network-online.target
Before=httpd.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/mount-efs.sh
ExecStop=/bin/umount /var/www/html

[Install]
WantedBy=multi-user.target
EOF

echo "==> Adding httpd systemd dependency on EFS mount"
mkdir -p /etc/systemd/system/httpd.service.d
cat > /etc/systemd/system/httpd.service.d/wait-for-efs.conf << 'EOF'
[Unit]
After=mount-efs.service
Requires=mount-efs.service
EOF

echo "==> Enabling services (will start on next boot after user-data configures EFS ID)"
systemctl daemon-reload
systemctl enable mount-efs.service
systemctl enable httpd
systemctl enable amazon-ssm-agent
systemctl enable amazon-cloudwatch-agent

echo "==> Blocking default Apache index page"
rm -f /var/www/html/index.html || true

echo "==> AMI build provisioning complete"
