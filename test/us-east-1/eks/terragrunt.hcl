locals {
  common      = read_terragrunt_config("${get_repo_root()}/_common/eks.hcl")
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
    intra_subnets   = ["subnet-00000000000000004", "subnet-00000000000000005", "subnet-00000000000000006"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=20.31.0"
}

inputs = merge(
  local.common.locals,
  {
    cluster_name = "lodge104-${local.env}"

    vpc_id                   = dependency.vpc.outputs.vpc_id
    subnet_ids               = dependency.vpc.outputs.private_subnets
    control_plane_subnet_ids = dependency.vpc.outputs.intra_subnets

    eks_managed_node_groups = {
      general = {
        min_size       = 1
        max_size       = 4
        desired_size   = 2
        instance_types = ["t3.large"]
        capacity_type  = "ON_DEMAND"
      }
    }
  }
)
