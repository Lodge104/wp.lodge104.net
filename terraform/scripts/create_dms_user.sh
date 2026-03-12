#!/bin/bash
# Runs on an EC2 WordPress instance via SSM Run Command.
# Reads all credentials from SSM Parameter Store — nothing is passed as an argument.
set -euo pipefail

echo "==> Resolving region from instance metadata"
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  "http://169.254.169.254/latest/meta-data/placement/region")

echo "==> Installing MySQL client (if not present)"
if ! command -v mysql &>/dev/null; then
  dnf install -y mariadb105 --quiet
fi

echo "==> Reading credentials from SSM"
DB_HOST=$(aws ssm get-parameter --name /lodge104/db/host \
  --region "$REGION" --query Parameter.Value --output text)
DB_USER=$(aws ssm get-parameter --name /lodge104/db/username \
  --region "$REGION" --query Parameter.Value --output text)
DB_PASS=$(aws ssm get-parameter --name /lodge104/db/password \
  --with-decryption --region "$REGION" --query Parameter.Value --output text)
DMS_PASS=$(aws ssm get-parameter --name /lodge104/dms/password \
  --with-decryption --region "$REGION" --query Parameter.Value --output text)

echo "==> Creating DMS MySQL user on $DB_HOST"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" <<SQL
CREATE USER IF NOT EXISTS 'dms_user'@'%' IDENTIFIED BY '$DMS_PASS';
GRANT REPLICATION CLIENT ON *.* TO 'dms_user'@'%';
GRANT REPLICATION SLAVE  ON *.* TO 'dms_user'@'%';
GRANT SELECT             ON *.* TO 'dms_user'@'%';
FLUSH PRIVILEGES;
SELECT User, Host FROM mysql.user WHERE User = 'dms_user';
SQL

echo "==> DMS user created successfully"
