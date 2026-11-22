# -----------------------------------------------------------------------------
# cloudfront-waf – WAFv2 web ACL (CLOUDFRONT scope) attached to the WordPress
# distribution.
#
# Full Terragrunt fragment included by <env>/<region>/cloudfront-waf/
# terragrunt.hcl. Env shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
}

terraform {
  source = "${get_repo_root()}//_modules/cloudfront-waf"
}

inputs = {
  name = "${local.ctx.name}-cloudfront"
}
