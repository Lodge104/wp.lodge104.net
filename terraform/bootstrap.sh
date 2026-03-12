#!/usr/bin/env bash
# ============================================================
# Bootstrap: creates the S3 bucket and DynamoDB table that
# Terraform needs for its remote state backend.
# Run this ONCE before `terraform init`.
# ============================================================
set -euo pipefail

BUCKET="lodge104-terraform-state"
TABLE="lodge104-terraform-locks"
REGION="us-east-1"

echo "==> Creating S3 state bucket: $BUCKET"
if aws s3api head-bucket --bucket "$BUCKET" --region "$REGION" 2>/dev/null; then
  echo "    Bucket already exists — skipping create"
else
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION"

  aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "$BUCKET" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

  aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  echo "    S3 bucket created and hardened"
fi

echo "==> Creating DynamoDB lock table: $TABLE"
if aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" 2>/dev/null; then
  echo "    Table already exists — skipping create"
else
  aws dynamodb create-table \
    --table-name "$TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"

  echo "    DynamoDB lock table created"
fi

echo ""
echo "==> Bootstrap complete. You can now run:"
echo "    cd terraform && terraform init"
