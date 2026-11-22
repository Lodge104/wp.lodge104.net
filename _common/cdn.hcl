# -----------------------------------------------------------------------------
# cdn – CloudFront + S3 bucket serving WordPress media uploads
# (cdn.<env>.wp.<domain>).
#
# Env-level knobs (<env>/env.hcl):
#   serves_root_domain  also alias cdn.<domain>
#   cdn_force_destroy   let destroy empty the bucket (default: !is_prod)
#
# Full Terragrunt fragment included by <env>/<region>/cdn/terragrunt.hcl. Env
# shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals

  force_destroy = try(local.ctx.env_vars.cdn_force_destroy, !local.ctx.is_prod)

  # CloudFront OAC names are account-global, so they're suffixed with the env.
  # Set cdn_origin_access_control_name = null in env.hcl to fall back to the
  # module default ("cdn").
  origin_access_control_name = try(local.ctx.env_vars.cdn_origin_access_control_name, "cdn-${local.ctx.env}")
}

terraform {
  source = "${get_repo_root()}/_modules/cloudfront"
}

dependency "acm" {
  config_path = "../acm"

  mock_outputs = {
    acm_certificate_arn = "arn:aws:acm:${local.ctx.region}:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = merge(
  {
    bucket_name = "${local.ctx.name}-cdn"
    comment     = "${local.ctx.project} ${local.ctx.env} uploads CDN"
    aliases = concat(
      ["cdn.${local.ctx.env_domain}"],
      local.ctx.serves_root_domain ? ["cdn.${local.ctx.domain}"] : [],
    )
    acm_certificate_arn = dependency.acm.outputs.acm_certificate_arn

    # PriceClass_100 (US/Canada/Europe) instead of All-edge-locations --
    # cost optimization, see issue #32. Revisit if global latency becomes a
    # real issue.
    price_class         = "PriceClass_100"
    is_ipv6_enabled     = true
    http_version        = "http2and3"
    wait_for_deployment = false
  },
  # Omitted when null so the module default ("cdn") applies -- Terragrunt
  # would otherwise pass an explicit null through to Terraform.
  local.origin_access_control_name != null ? { origin_access_control_name = local.origin_access_control_name } : {},
  # Only passed when enabled (prod relies on the module default of false).
  local.force_destroy ? { force_destroy = true } : {},
)
