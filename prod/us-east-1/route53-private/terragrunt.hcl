locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/route53.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env    = local.env_vars.locals.env
  region = local.region_vars.locals.aws_region
  domain = local.project_vars.locals.domain
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    cluster_endpoint = "lodge104-prod.cluster-xxxxxxxxxxxx.us-east-1.rds.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "elasticache" {
  config_path = "../elasticache"

  mock_outputs = {
    cluster_address = "lodge104-prod.xxxxxx.cfg.use1.cache.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

inputs = merge(
  local.common.locals,
  {
    create_zone = true
    name        = "${local.env}.wp.${local.domain}"
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
      cache = {
        name    = "cache"
        type    = "CNAME"
        ttl     = 300
        records = [dependency.elasticache.outputs.cluster_address]
      }
    }
  }
)
