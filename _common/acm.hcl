# -----------------------------------------------------------------------------
# acm – TLS certificate for the env's CloudFront distributions
# (<env>.wp.<domain>, *.<env>.wp.<domain>).
#
# Env-level knob (<env>/env.hcl):
#   serves_root_domain  also cover the apex domain + www./store./cdn. SANs.
#                       Those must be DNS-validated in the parent <domain>
#                       zone, not the delegated <env>.wp.<domain> zone.
#
# Full Terragrunt fragment included by <env>/<region>/acm/terragrunt.hcl. Env
# shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals

  # Mock zone IDs per env (only used before global/route53-<env> is applied).
  mock_zone_ids = { dev = "Z1111111111111", test = "Z2222222222222", prod = "Z3333333333333" }

  root_domain_sans = [
    local.ctx.domain,
    "www.${local.ctx.domain}",
    "store.${local.ctx.domain}",
    "cdn.${local.ctx.domain}",
  ]
}

terraform {
  source = "tfr:///terraform-aws-modules/acm/aws?version=5.1.1"
}

# The env's delegated zone. Also a dependency when validating in the parent
# zone, so the env zone/delegation is always created first.
dependency "zone" {
  config_path = "${get_repo_root()}/global/route53-${local.ctx.env}"

  mock_outputs = {
    id = lookup(local.mock_zone_ids, local.ctx.env, "Z0000000000000")
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  domain_name = local.ctx.env_domain
  subject_alternative_names = concat(
    ["*.${local.ctx.env_domain}"],
    local.ctx.serves_root_domain ? local.root_domain_sans : [],
  )

  validation_method   = "DNS"
  wait_for_validation = true

  zone_id = local.ctx.serves_root_domain ? local.ctx.parent_zone_id : dependency.zone.outputs.id
}
