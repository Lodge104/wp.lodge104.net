locals {
  common      = read_terragrunt_config("${get_repo_root()}/_common/elasticache.hcl")
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
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    node_security_group_id = "sg-00000000000000001"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

terraform {
  source = "tfr:///terraform-aws-modules/elasticache/aws?version=1.3.0"
}

inputs = merge(
  local.common.locals,
  {
    cluster_id = "lodge104-${local.env}"

    num_cache_nodes = 2
    node_type       = "cache.t3.small"

    subnet_ids = dependency.vpc.outputs.private_subnets
    vpc_id     = dependency.vpc.outputs.vpc_id

    security_group_rules = {
      eks_ingress = {
        description                   = "Memcached from EKS nodes"
        referenced_security_group_id = dependency.eks.outputs.node_security_group_id
      }
    }
  }
)
