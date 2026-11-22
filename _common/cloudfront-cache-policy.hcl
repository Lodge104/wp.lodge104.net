# -----------------------------------------------------------------------------
# cloudfront-cache-policy – response headers policy that forces a long-lived,
# immutable Cache-Control on the WordPress distribution's static-asset
# behaviors (themes/plugins/wp-includes/uploads) served via the ALB origin,
# regardless of what the origin sends.
#
# Full Terragrunt fragment included by <env>/<region>/cloudfront-cache-policy/
# terragrunt.hcl. Env shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
}

terraform {
  source = "${get_repo_root()}/_modules/response-headers-policy"
}

inputs = {
  name = "${local.ctx.name}-static-assets-cache"
}
