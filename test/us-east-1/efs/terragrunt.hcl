locals {
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

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name           = "lodge104-test"
    node_security_group_id = "sg-00000000000000001"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "${get_repo_root()}//_modules/efs"
}

inputs = {
  name                       = "lodge104-${local.env}"
  vpc_id                     = dependency.vpc.outputs.vpc_id
  subnet_ids                 = dependency.vpc.outputs.private_subnets
  eks_cluster_name           = dependency.eks.outputs.cluster_name
  eks_node_security_group_id = dependency.eks.outputs.node_security_group_id

  throughput_mode = "elastic"
}
