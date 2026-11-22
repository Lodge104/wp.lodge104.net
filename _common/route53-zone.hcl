# -----------------------------------------------------------------------------
# route53-zone – public hosted zone with DNSSEC, one per env
# (<env>.wp.<domain>, from global/route53-<env>) plus the shared
# wp.<domain> parent of those (global/route53-wp).
#
# The zone name is derived from the stack folder (global/route53-<env> ->
# "<env>.wp.<domain>", global/route53-wp -> "wp.<domain>"); a shim can still
# override it with a one-line `inputs = { name = ... }`.
#
# Full Terragrunt fragment included by global/route53-{dev,test,prod,wp}/
# terragrunt.hcl.
# -----------------------------------------------------------------------------

locals {
  ctx    = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  shared = read_terragrunt_config("${get_repo_root()}/_common/shared/route53.hcl").locals

  zone_env = trimprefix(local.ctx.stack_name, "route53-")

  # global/route53-wp holds the shared wp.<domain> parent of the env zones;
  # every other global/route53-<env> is <env>.wp.<domain>.
  zone_name = local.zone_env == "wp" ? "wp.${local.ctx.domain}" : "${local.zone_env}.wp.${local.ctx.domain}"
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

inputs = merge(
  local.shared,
  {
    create_zone   = true
    name          = local.zone_name
    enable_dnssec = true
    records       = {}
  }
)
