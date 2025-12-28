#!/bin/bash
set -e

WP_DIR="/var/www/efs/wordpress"

echo "WordPress Setup Script Starting..."

# Create WordPress directory if it doesn't exist
mkdir -p "$WP_DIR"

# Only download WordPress if wp-settings.php doesn't exist (first time setup)
if [ ! -f "$WP_DIR/wp-settings.php" ]; then
    echo "WordPress not found, downloading (this may take a few minutes)..."
    cd /tmp
    timeout 120 curl -O https://wordpress.org/latest.tar.gz || echo "Download timed out, skipping"
    
    if [ -f latest.tar.gz ]; then
        tar -xzf latest.tar.gz
        cp -rn wordpress/* "$WP_DIR/" 2>/dev/null || true
        rm -rf wordpress latest.tar.gz
        echo "WordPress downloaded"
    else
        echo "WordPress download failed, assuming it exists on EFS"
    fi
else
    echo "WordPress already exists at $WP_DIR"
fi

# Install PHP MySQL extension if needed (quick check)
php -m | grep -q mysqli || dnf install -y php-mysqlnd

# Set proper permissions
chown -R webapp:webapp "$WP_DIR"

echo "WordPress setup complete"
