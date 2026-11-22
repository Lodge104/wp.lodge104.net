# -----------------------------------------------------------------------------
# route53-parent – NS + DS delegation of wp.<domain> (global/route53-wp) from
# the apex <domain> public zone.
#
# Full Terragrunt fragment included by global/route53-parent/terragrunt.hcl.
# -----------------------------------------------------------------------------

locals {
  ctx    = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  shared = read_terragrunt_config("${get_repo_root()}/_common/shared/route53.hcl").locals
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

dependency "wp_zone" {
  config_path = "../route53-wp"

  mock_outputs = {
    name_servers = [
      "ns-123.awsdns-01.net",
      "ns-456.awsdns-02.org",
      "ns-789.awsdns-03.co.uk",
      "ns-012.awsdns-04.com",
    ]
    dnssec_signing_key_ds_record = "12345 13 2 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  }
  # Mocks also run during `apply` (route53-wp is created in the same
  # `run --all apply` as this stack on a fresh account).
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

inputs = merge(
  local.shared,
  {
    name = local.ctx.domain
    records = {
      wp_delegation = {
        name    = "wp"
        type    = "NS"
        ttl     = 300
        records = dependency.wp_zone.outputs.name_servers
      }
      wp_ds = {
        name    = "wp"
        type    = "DS"
        ttl     = 300
        records = compact([try(dependency.wp_zone.outputs.dnssec_signing_key_ds_record, null)])
      }
    }
  }
)
