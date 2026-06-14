locals {
  common      = read_terragrunt_config("${get_repo_root()}/_common/rds.hcl")
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  env    = local.env_vars.locals.env
  region = local.region_vars.locals.aws_region
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id          = "vpc-00000000000000000"
    private_subnets = ["subnet-00000000000000001", "subnet-00000000000000002", "subnet-00000000000000003"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.10.0"
}

inputs = merge(
  local.common.locals,
  {
    identifier = "lodge104-${local.env}"

    instance_class        = "db.r6g.large"
    allocated_storage     = 100
    max_allocated_storage = 1000

    db_subnet_group_name   = "lodge104-${local.env}"
    subnet_ids             = dependency.vpc.outputs.private_subnets
    vpc_security_group_ids = []

    multi_az            = true
    deletion_protection = true
    skip_final_snapshot = false

    backup_retention_period = 30

    performance_insights_retention_period = 731 # maximum 2 years
  }
)
