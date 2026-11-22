# -----------------------------------------------------------------------------
# cloudfront-logs – S3 bucket receiving the env's CloudFront standard access
# logs (enabled per env by `cloudfront_access_logs = true` in env.hcl, see
# _common/cloudfront.hcl). Objects expire after `retention_days`.
#
# Full Terragrunt fragment included by <env>/<region>/cloudfront-logs/
# terragrunt.hcl (currently prod only).
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
}

terraform {
  source = "${get_repo_root()}//_modules/cloudfront-logs"
}

inputs = {
  bucket_name    = "${local.ctx.name}-cloudfront-logs"
  retention_days = 30
}
