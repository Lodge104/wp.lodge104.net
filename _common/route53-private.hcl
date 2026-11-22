# -----------------------------------------------------------------------------
# route53-private – private hosted zone <env>.wp.<domain> attached to the env
# VPC, with in-VPC aliases for backing services (e.g. database.<env>.wp...).
#
# ElastiCache dependency and "cache" record removed -- WordPress now uses the
# in-cluster Memcached sub-chart instead of the managed ElastiCache service.
# See issue #32.
#
# Full Terragrunt fragment included by <env>/<region>/route53-private/
# terragrunt.hcl. Env shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx     = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  route53 = read_terragrunt_config("${get_repo_root()}/_common/shared/route53.hcl").locals
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    cluster_endpoint = "${local.ctx.name}.cluster-xxxxxxxxxxxx.${local.ctx.region}.rds.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = merge(
  local.route53,
  {
    create_zone = true
    name        = local.ctx.env_domain
    vpc = {
      main = { vpc_id = dependency.vpc.outputs.vpc_id }
    }
    records = {
      database = {
        name    = "database"
        type    = "CNAME"
        ttl     = 300
        records = [dependency.rds.outputs.cluster_endpoint]
      }
    }
  }
)
