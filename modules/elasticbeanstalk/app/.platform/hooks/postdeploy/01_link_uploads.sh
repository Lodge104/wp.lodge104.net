#!/bin/bash
APP_DEPLOY_DIR="/var/app/current"
EFS_MOUNT_DIR="/mnt/efs"
UPLOADS_DIR="${APP_DEPLOY_DIR}/wp-content/uploads"
EFS_UPLOADS_DIR="${EFS_MOUNT_DIR}/uploads"

# Ensure EFS uploads directory exists
mkdir -p ${EFS_UPLOADS_DIR}
chown webapp:webapp ${EFS_UPLOADS_DIR}

# Remove local uploads folder if it exists (from git/bundle) and is empty
if [ -d "${UPLOADS_DIR}" ]; then
    rm -rf "${UPLOADS_DIR}"
fi

# Create symlink
# Ensure parent directory exists
mkdir -p "${APP_DEPLOY_DIR}/wp-content"
ln -s ${EFS_UPLOADS_DIR} ${UPLOADS_DIR}

# Fix permissions again just in case
chown -h webapp:webapp ${UPLOADS_DIR}
