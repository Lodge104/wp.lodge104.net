# -----------------------------------------------------------------------------
# route53-env-delegation – NS + DS delegation records in wp.<domain> for each
# env zone (<env>.wp.<domain>, managed by global/route53-<env>).
#
# Dependencies can't be generated in a loop, so there's one static
# dependency block per env; the records map is built with a `for` expression
# over local.envs.
#
# Full Terragrunt fragment included by global/route53-env-delegation/
# terragrunt.hcl.
# -----------------------------------------------------------------------------

locals {
  ctx    = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  shared = read_terragrunt_config("${get_repo_root()}/_common/shared/route53.hcl").locals

  # Mocks also run during `apply` (the zones are created in the same
  # `run --all apply` as this stack on a fresh account).
  mock_cmds = ["init", "validate", "plan", "apply", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

dependency "prod_zone" {
  config_path = "${get_repo_root()}/global/route53-prod"

  mock_outputs = {
    name_servers = [
      "ns-111.awsdns-01.net",
      "ns-222.awsdns-02.org",
      "ns-333.awsdns-03.co.uk",
      "ns-444.awsdns-04.com",
    ]
    dnssec_signing_key_ds_record = "12345 13 2 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  }
  mock_outputs_allowed_terraform_commands = local.mock_cmds
}

dependency "dev_zone" {
  config_path = "${get_repo_root()}/global/route53-dev"

  mock_outputs = {
    name_servers = [
      "ns-555.awsdns-01.net",
      "ns-666.awsdns-02.org",
      "ns-777.awsdns-03.co.uk",
      "ns-888.awsdns-04.com",
    ]
    dnssec_signing_key_ds_record = "12345 13 2 BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
  }
  mock_outputs_allowed_terraform_commands = local.mock_cmds
}

dependency "test_zone" {
  config_path = "${get_repo_root()}/global/route53-test"

  mock_outputs = {
    name_servers = [
      "ns-999.awsdns-01.net",
      "ns-000.awsdns-02.org",
      "ns-121.awsdns-03.co.uk",
      "ns-131.awsdns-04.com",
    ]
    dnssec_signing_key_ds_record = "12345 13 2 CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
  }
  mock_outputs_allowed_terraform_commands = local.mock_cmds
}

inputs = merge(
  local.shared,
  {
    name = "wp.${local.ctx.domain}"
    records = merge([
      for env, zone in {
        prod = dependency.prod_zone.outputs
        dev  = dependency.dev_zone.outputs
        test = dependency.test_zone.outputs
        } : {
        "${env}_delegation" = {
          name    = env
          type    = "NS"
          ttl     = 300
          records = zone.name_servers
        }
        "${env}_ds" = {
          name    = env
          type    = "DS"
          ttl     = 300
          records = compact([try(zone.dnssec_signing_key_ds_record, null)])
        }
      }
    ]...)
  }
)
