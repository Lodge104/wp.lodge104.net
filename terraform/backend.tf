# ============================================================
# Terraform Remote State — S3 + DynamoDB
# ============================================================
# BOOTSTRAP REQUIRED before first `terraform init`:
#
#   aws s3api create-bucket \
#     --bucket lodge104-terraform-state \
#     --region us-east-1
#
#   aws s3api put-bucket-versioning \
#     --bucket lodge104-terraform-state \
#     --versioning-configuration Status=Enabled
#
#   aws s3api put-bucket-encryption \
#     --bucket lodge104-terraform-state \
#     --server-side-encryption-configuration \
#     '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#
#   aws s3api put-public-access-block \
#     --bucket lodge104-terraform-state \
#     --public-access-block-configuration \
#     "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
#
#   aws dynamodb create-table \
#     --table-name lodge104-terraform-locks \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region us-east-1
#
# Or run: bash bootstrap.sh
# ============================================================

terraform {
  backend "s3" {
    bucket         = "lodge104-terraform-state"
    key            = "lodge104.net/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "lodge104-terraform-locks"
    encrypt        = true
  }
}
