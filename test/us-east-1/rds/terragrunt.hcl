locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/rds.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  region  = local.region_vars.locals.aws_region
  project = local.project_vars.locals.project_name
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
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    node_security_group_id = "sg-00000000000000001"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/rds-aurora/aws?version=9.3.0"

  extra_arguments "final_snapshot" {
    commands = ["destroy"]
    arguments = [
      "-var=final_snapshot_identifier=${local.project}-${local.env}-final",
      "-var=skip_final_snapshot=false",
    ]
  }
}

inputs = merge(
  local.common.locals,
  {
    name = "${local.project}-${local.env}"

    # Serverless v2 scaling – moderate capacity ceiling for test workloads
    serverlessv2_scaling_configuration = local.env_vars.locals.rds_scaling

    instances = local.env_vars.locals.rds_instances

    db_subnet_group_name   = "${local.project}-${local.env}"
    subnets                = dependency.vpc.outputs.private_subnets
    vpc_id                 = dependency.vpc.outputs.vpc_id
    vpc_security_group_ids = []

    security_group_rules = {
      eks_ingress = {
        description              = "MySQL from EKS nodes"
        source_security_group_id = dependency.eks.outputs.node_security_group_id
      }
    }

    deletion_protection = false
    skip_final_snapshot       = false
    final_snapshot_identifier = "${local.project}-${local.env}-final"
  }
)
