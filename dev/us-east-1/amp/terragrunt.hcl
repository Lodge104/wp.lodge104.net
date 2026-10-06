locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/amp.hcl")
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

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_arn                = "arn:aws:eks:${local.region}:000000000000:cluster/${local.project}-${local.env}"
    cluster_security_group_id  = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "vpc" {
  config_path = "../vpc"

  # The AMP scraper's ENIs must land in subnets actually associated with the
  # EKS cluster's VPC config. This cluster's worker nodes run in the public
  # subnets and the control plane uses the intra subnets (NAT Gateway was
  # removed, see issue #32) -- the intra subnets are what EKS reports back
  # as the cluster's resourcesVpcConfig.subnetIds, so that's what the
  # scraper has to use (private_subnets are unrelated to this cluster and
  # the scraper creation fails with "Subnet ... is not associated with
  # provided EKS Cluster").
  mock_outputs = {
    intra_subnets = ["subnet-00000000000000001", "subnet-00000000000000002", "subnet-00000000000000003"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${get_repo_root()}//_modules/amp"
}

inputs = merge(
  local.common.locals,
  {
    workspace_alias               = "${local.project}-${local.env}"
    eks_cluster_arn                = dependency.eks.outputs.cluster_arn
    eks_cluster_security_group_id  = dependency.eks.outputs.cluster_security_group_id
    subnet_ids                     = dependency.vpc.outputs.intra_subnets
  }
)
