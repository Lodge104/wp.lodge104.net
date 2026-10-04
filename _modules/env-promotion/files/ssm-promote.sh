#!/bin/bash
# ---------------------------------------------------------------------------
# Copies the WordPress Aurora MySQL database, EFS content, and CDN S3
# bucket from one environment to another, then runs a serialization-safe
# `wp search-replace` in the target cluster to fix up the domain baked into
# the copied database. Runs as an SSM Command document on the project
# bastion host, which already has:
#   - VPC peering + security-group ingress to every environment's RDS
#     cluster and EFS file system (see _modules/bastion)
#   - every environment's EFS file system mounted under /mnt/efs/<token>
#     (at the filesystem root -- the WordPress-data subdirectory under
#     that root is resolved dynamically per-environment, see step 2 below)
#   - the mariadb client, rsync, kubectl, and the AWS CLI installed
#   - IAM permissions for rds:DescribeDBClusters, reading the RDS-managed
#     master user secrets, eks:DescribeCluster, elasticfilesystem:Describe*,
#     and the per-environment *-cdn S3 buckets (granted alongside this
#     module -- see _modules/bastion/main.tf)
#   - a Kubernetes access entry + namespace-scoped AmazonEKSEditPolicy on
#     every promotion *target* cluster (granted in this module's main.tf),
#     which is what makes the kubectl exec in step 4 authorized. Source
#     clusters need no kubectl access -- the EFS access-point lookup in
#     step 2 goes through the EFS API directly.
#
# Parameters (substituted by SSM before this script runs):
#   ProjectName, SourceEnv, TargetEnv, Region, Domain, ReleaseName, Namespace
#
# NOTE on why search-replace instead of a dump-time text substitution: a
# naive find/replace on the SQL dump would corrupt PHP-serialized values
# (e.g. serialized arrays in wp_options) whose byte-length prefixes no
# longer match once the replacement string has a different length.
# `wp search-replace` understands PHP serialization and rewrites those
# length prefixes correctly, so it runs afterwards, in-place, against the
# already-restored target database.
# ---------------------------------------------------------------------------
set -euo pipefail

PROJECT="{{ ProjectName }}"
SRC_ENV="{{ SourceEnv }}"
DST_ENV="{{ TargetEnv }}"
REGION="{{ Region }}"
DOMAIN="{{ Domain }}"
RELEASE_NAME="{{ ReleaseName }}"
NAMESPACE="{{ Namespace }}"

# Matches _common/rds.hcl -- shared across every environment's cluster.
DB_NAME="lodge104"
DB_USER="lodge104admin"

SRC_CLUSTER="${PROJECT}-${SRC_ENV}"
DST_CLUSTER="${PROJECT}-${DST_ENV}"

# Matches the wordpressHost/multisite.host convention in each env's
# terragrunt.hcl (_common/wordpress.hcl base_values + per-env overrides):
# prod uses the bare domain, every other environment uses <env>.wp.<domain>.
env_hostname() {
  if [ "$1" = "prod" ]; then
    echo "$DOMAIN"
  else
    echo "$1.wp.$DOMAIN"
  fi
}

SRC_HOST=$(env_hostname "$SRC_ENV")
DST_HOST=$(env_hostname "$DST_ENV")

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

log "=== Starting promotion: ${PROJECT} ${SRC_ENV} -> ${DST_ENV} ==="

# ---------------------------------------------------------------------------
# 0. Resolve the target cluster's kubeconfig up front (needed later for the
#    wp search-replace exec in step 4).
# ---------------------------------------------------------------------------
DST_KUBECONFIG=$(mktemp)
trap 'rm -f "$DUMP_FILE" "$DST_KUBECONFIG"' EXIT

log "Resolving kubeconfig for ${DST_CLUSTER}..."
KUBECONFIG="$DST_KUBECONFIG" aws eks update-kubeconfig --name "$DST_CLUSTER" --region "$REGION" >/dev/null

# Resolves the absolute path (relative to the EFS filesystem root) that the
# given environment's WordPress data actually lives under. The EFS CSI
# driver's "efs-ap" provisioning mode (see _modules/efs's efs-sc
# StorageClass) creates one access point per PVC, rooted at a randomly
# named subdirectory (e.g. /pvc-<uuid>) -- NOT the filesystem root -- so
# this must be resolved per-environment via the EFS API rather than
# assumed. This looks up the access point purely via "<project>-<env>"'s
# EFS filesystem (by its creation token), with no kubectl/EKS dependency.
efs_access_point_path() {
  local cluster="$1"
  local fs_id ap_count path

  fs_id=$(aws efs describe-file-systems --region "$REGION" \
    --query "FileSystems[?CreationToken=='${cluster}'].FileSystemId" --output text)
  if [ -z "$fs_id" ] || [ "$fs_id" = "None" ]; then
    echo "Could not find an EFS file system with creation token '${cluster}'." >&2
    return 1
  fi

  ap_count=$(aws efs describe-access-points --file-system-id "$fs_id" --region "$REGION" \
    --query 'length(AccessPoints)' --output text)
  if [ "$ap_count" != "1" ]; then
    echo "Expected exactly 1 EFS access point on file system ${fs_id} (${cluster}), found ${ap_count}. Refusing to guess which one backs the WordPress PVC." >&2
    return 1
  fi

  path=$(aws efs describe-access-points --file-system-id "$fs_id" --region "$REGION" \
    --query 'AccessPoints[0].RootDirectory.Path' --output text)
  if [ -z "$path" ] || [ "$path" = "None" ]; then
    echo "Could not resolve RootDirectory.Path for the access point on file system ${fs_id} (${cluster})." >&2
    return 1
  fi

  echo "$path"
}

# ---------------------------------------------------------------------------
# 1. Aurora MySQL database: mysqldump the source cluster, mysql-import into
#    the target cluster. Endpoints and the RDS-managed master user secret
#    ARNs are resolved dynamically so this script needs no
#    environment-specific wiring.
# ---------------------------------------------------------------------------
log "Resolving RDS cluster endpoints and credentials..."

SRC_ENDPOINT=$(aws rds describe-db-clusters --region "$REGION" \
  --db-cluster-identifier "$SRC_CLUSTER" \
  --query 'DBClusters[0].Endpoint' --output text)
DST_ENDPOINT=$(aws rds describe-db-clusters --region "$REGION" \
  --db-cluster-identifier "$DST_CLUSTER" \
  --query 'DBClusters[0].Endpoint' --output text)

SRC_SECRET_ARN=$(aws rds describe-db-clusters --region "$REGION" \
  --db-cluster-identifier "$SRC_CLUSTER" \
  --query 'DBClusters[0].MasterUserSecret.SecretArn' --output text)
DST_SECRET_ARN=$(aws rds describe-db-clusters --region "$REGION" \
  --db-cluster-identifier "$DST_CLUSTER" \
  --query 'DBClusters[0].MasterUserSecret.SecretArn' --output text)

SRC_PASSWORD=$(aws secretsmanager get-secret-value --region "$REGION" \
  --secret-id "$SRC_SECRET_ARN" --query SecretString --output text \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["password"])')
DST_PASSWORD=$(aws secretsmanager get-secret-value --region "$REGION" \
  --secret-id "$DST_SECRET_ARN" --query SecretString --output text \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["password"])')

DUMP_FILE="/tmp/${PROJECT}-${SRC_ENV}-to-${DST_ENV}.sql"
# NOTE: the EXIT trap covering $DUMP_FILE and $DST_KUBECONFIG together was
# already registered in step 0 above -- do not re-register it here, a
# second `trap ... EXIT` would replace (not add to) the first and silently
# drop the kubeconfig cleanup.

log "Dumping ${SRC_CLUSTER} (${SRC_ENDPOINT})..."
MYSQL_PWD="$SRC_PASSWORD" mysqldump -h "$SRC_ENDPOINT" -u "$DB_USER" \
  --single-transaction --quick --routines --triggers "$DB_NAME" > "$DUMP_FILE"

log "Restoring into ${DST_CLUSTER} (${DST_ENDPOINT})..."
MYSQL_PWD="$DST_PASSWORD" mysql -h "$DST_ENDPOINT" -u "$DB_USER" "$DB_NAME" < "$DUMP_FILE"

log "Database copy complete."

# ---------------------------------------------------------------------------
# 2. EFS: both environments are already mounted on this bastion at their
#    filesystem roots (see mount-env-efs.sh in _modules/bastion), but each
#    cluster's WordPress data actually lives under a per-install EFS
#    access-point subdirectory, not the filesystem root. Resolve each
#    environment's real subdirectory and rsync *those*, not the roots --
#    syncing the roots with --delete would wipe the target's access-point
#    directory (it doesn't exist in the source tree) while depositing the
#    source's content under a path the target's pod never mounts.
# ---------------------------------------------------------------------------
log "Resolving EFS access-point root directories for ${SRC_CLUSTER} and ${DST_CLUSTER}..."
SRC_AP_PATH=$(efs_access_point_path "$SRC_CLUSTER")
DST_AP_PATH=$(efs_access_point_path "$DST_CLUSTER")

# Safety net: refuse to proceed if either path resolved to the filesystem
# root -- that's exactly the condition that caused a prior incident where
# `rsync --delete` wiped out a target environment's live WordPress files.
if [ -z "$SRC_AP_PATH" ] || [ "$SRC_AP_PATH" = "/" ] || [ -z "$DST_AP_PATH" ] || [ "$DST_AP_PATH" = "/" ]; then
  echo "Refusing to sync: resolved EFS access-point path was empty or '/' (source='${SRC_AP_PATH}', target='${DST_AP_PATH}'). This would sync/delete at the filesystem root instead of the per-install subdirectory." >&2
  exit 1
fi

SRC_EFS="/mnt/efs/${SRC_CLUSTER}${SRC_AP_PATH}"
DST_EFS="/mnt/efs/${DST_CLUSTER}${DST_AP_PATH}"

if [ ! -d "$SRC_EFS" ] || [ ! -d "$DST_EFS" ]; then
  echo "Expected EFS access-point directories not found: ${SRC_EFS} / ${DST_EFS}" >&2
  exit 1
fi

log "Syncing EFS ${SRC_EFS} -> ${DST_EFS}..."
rsync -a --delete "${SRC_EFS}/" "${DST_EFS}/"
log "EFS copy complete."

# ---------------------------------------------------------------------------
# 3. CDN S3 bucket (WP Offload Media uploads).
# ---------------------------------------------------------------------------
SRC_BUCKET="${SRC_CLUSTER}-cdn"
DST_BUCKET="${DST_CLUSTER}-cdn"

log "Syncing s3://${SRC_BUCKET} -> s3://${DST_BUCKET}..."
aws s3 sync "s3://${SRC_BUCKET}" "s3://${DST_BUCKET}" --delete --region "$REGION"
log "S3 copy complete."

# ---------------------------------------------------------------------------
# 4. Domain rewrite: the copied database still has the source environment's
#    hostname (siteurl/home/wp_blogs.domain/wp_site.domain, etc.) baked in.
#    Rewrite it in-place via WP-CLI's serialization-safe search-replace,
#    run inside a live WordPress pod in the target cluster (so it uses the
#    same PHP/WP-CLI version and DB connection as the app itself). Reuses
#    the DST_KUBECONFIG resolved in step 0.
# ---------------------------------------------------------------------------
POD_NAME=$(KUBECONFIG="$DST_KUBECONFIG" kubectl get pods -n "$NAMESPACE" \
  -l "app.kubernetes.io/instance=${RELEASE_NAME}" \
  -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
  echo "No WordPress pod found in namespace ${NAMESPACE} (release ${RELEASE_NAME}) on ${DST_CLUSTER}; skipping domain rewrite." >&2
  exit 1
fi

log "Running wp search-replace '${SRC_HOST}' -> '${DST_HOST}' in pod ${POD_NAME}..."
KUBECONFIG="$DST_KUBECONFIG" kubectl exec -n "$NAMESPACE" "$POD_NAME" -c wordpress -- \
  wp search-replace "$SRC_HOST" "$DST_HOST" --all-tables --network --report-changed-only

# The origin.<host> ALB rule (see dev/us-east-1/wordpress/terragrunt.hcl)
# is also baked into some rows (e.g. canonical redirects cached by plugins);
# rewrite it too so internal origin-facing requests still resolve correctly.
log "Running wp search-replace 'origin.${SRC_HOST}' -> 'origin.${DST_HOST}' in pod ${POD_NAME}..."
KUBECONFIG="$DST_KUBECONFIG" kubectl exec -n "$NAMESPACE" "$POD_NAME" -c wordpress -- \
  wp search-replace "origin.$SRC_HOST" "origin.$DST_HOST" --all-tables --network --report-changed-only

log "Domain rewrite complete."

log "=== Promotion complete: ${PROJECT} ${SRC_ENV} -> ${DST_ENV} ==="
