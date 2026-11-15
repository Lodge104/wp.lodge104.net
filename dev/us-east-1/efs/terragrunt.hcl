locals {
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
    cluster_name                       = "${local.project}-${local.env}"
    cluster_endpoint                   = "https://example.eks.amazonaws.com"
    cluster_certificate_authority_data = base64encode(file("${get_repo_root()}/_common/mock-ca.pem"))
    node_security_group_id             = "sg-00000000000000001"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${get_repo_root()}//_modules/efs"
}

inputs = {
  name                       = "${local.project}-${local.env}"
  vpc_id                     = dependency.vpc.outputs.vpc_id
  subnet_ids                 = dependency.vpc.outputs.private_subnets
  eks_cluster_name           = dependency.eks.outputs.cluster_name
  eks_cluster_endpoint       = dependency.eks.outputs.cluster_endpoint

  eks_cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  eks_node_security_group_id = dependency.eks.outputs.node_security_group_id
  region                     = local.region

  throughput_mode = "elastic"
}
