#!/bin/bash
set -e

WP_DIR="/var/www/efs/wordpress"
WP_CONFIG="$WP_DIR/wp-config.php"

# Only create wp-config.php if it doesn't exist
if [ -f "$WP_CONFIG" ]; then
    echo "wp-config.php already exists, skipping creation"
    exit 0
fi

if [ ! -f "$WP_DIR/wp-config-sample.php" ]; then
    echo "WordPress not installed yet, skipping wp-config creation"
    exit 0
fi

echo "Creating wp-config.php from environment variables..."

# Get database credentials from environment
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASSWORD="${DB_PASSWORD}"
DB_HOST="${DB_HOST}"
DOMAIN_NAME="${PRIMARY_DOMAIN}"

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_HOST" ]; then
    echo "ERROR: Database environment variables not set"
    echo "DB_NAME=$DB_NAME"
    echo "DB_USER=$DB_USER"
    echo "DB_HOST=$DB_HOST"
    exit 1
fi

# Copy sample config
cp "$WP_DIR/wp-config-sample.php" "$WP_CONFIG"

# Replace database settings
sed -i "s/database_name_here/$DB_NAME/g" "$WP_CONFIG"
sed -i "s/username_here/$DB_USER/g" "$WP_CONFIG"
sed -i "s/password_here/$DB_PASSWORD/g" "$WP_CONFIG"
sed -i "s/localhost/$DB_HOST/g" "$WP_CONFIG"

# Generate unique salts
SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s "$WP_CONFIG"

# Add WP_HOME and WP_SITEURL if domain is set
if [ -n "$DOMAIN_NAME" ]; then
    sed -i "/\/\* That's all, stop editing/i \
define('WP_HOME', 'https://$DOMAIN_NAME');\n\
define('WP_SITEURL', 'https://$DOMAIN_NAME');\n" "$WP_CONFIG"
fi

# Set proper permissions
chown webapp:webapp "$WP_CONFIG"
chmod 640 "$WP_CONFIG"

echo "wp-config.php created successfully"
