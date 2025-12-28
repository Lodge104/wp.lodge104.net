#!/bin/bash
EFS_MOUNT_DIR="/mnt/efs"
EFS_FILE_SYSTEM_ID=$(/opt/elasticbeanstalk/bin/get-config environment -k EFS_FILE_SYSTEM_ID)

echo "Mounting EFS filesystem ${EFS_FILE_SYSTEM_ID} to ${EFS_MOUNT_DIR}..."

mkdir -p ${EFS_MOUNT_DIR}

# Check if already mounted
if ! mount | grep -q "${EFS_MOUNT_DIR}"; then
    # Mount using IAM role (requires 'efs:ClientMount' permission in instance profile)
    mount -t efs -o tls,iam ${EFS_FILE_SYSTEM_ID}:/ ${EFS_MOUNT_DIR}
    if [ $? -ne 0 ]; then
        echo "ERROR: Mount failed."
        exit 1
    fi
    echo "Mount successful."
else
    echo "EFS already mounted."
fi

# Set permissions for the web user (webapp on AL2023 PHP platform)
chown -R webapp:webapp ${EFS_MOUNT_DIR}
chmod 775 ${EFS_MOUNT_DIR}
