#!/bin/bash
set -e

# Install EFS utils if not already installed
if ! command -v mount.efs &> /dev/null; then
    dnf install -y amazon-efs-utils
fi

# Get EFS ID from environment variables
EFS_ID="${EFS_FILE_SYSTEM_ID}"
MOUNT_POINT="/var/www/efs"

echo "EFS Mount Script Starting..."
echo "EFS ID: $EFS_ID"
echo "Mount Point: $MOUNT_POINT"

if [ -z "$EFS_ID" ]; then
    echo "ERROR: EFS_FILE_SYSTEM_ID environment variable not set"
    exit 1
fi

# Create mount point if it doesn't exist
mkdir -p "$MOUNT_POINT"

# Check if already mounted
if mountpoint -q "$MOUNT_POINT"; then
    echo "EFS already mounted at $MOUNT_POINT"
    exit 0
fi

# Mount EFS with TLS
echo "Mounting EFS $EFS_ID to $MOUNT_POINT..."
mount -t efs -o tls "$EFS_ID":/ "$MOUNT_POINT"

# Add to fstab if not already there
if ! grep -q "$EFS_ID" /etc/fstab; then
    echo "$EFS_ID:/ $MOUNT_POINT efs defaults,_netdev,tls 0 0" >> /etc/fstab
fi

# Set proper permissions
chown -R webapp:webapp "$MOUNT_POINT"
chmod 755 "$MOUNT_POINT"

echo "EFS mounted successfully"
