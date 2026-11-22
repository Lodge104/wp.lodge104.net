# -----------------------------------------------------------------------------
# wordpress-s3-access – IAM policy granting WordPress access to the env's CDN
# uploads bucket (attached to the EKS node role by the eks stack).
#
# Full Terragrunt fragment included by <env>/<region>/wordpress-s3-access/
# terragrunt.hcl. Env shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx    = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  bucket = "${local.ctx.name}-cdn"
}

terraform {
  source = "${get_repo_root()}/_modules/wordpress-s3-access"
}

inputs = {
  bucket_name = local.bucket
  bucket_arn  = "arn:aws:s3:::${local.bucket}"
  policy_name = "${local.ctx.name}-wordpress-s3-access"
}
