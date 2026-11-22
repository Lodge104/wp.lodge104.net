# -----------------------------------------------------------------------------
# amp – Amazon Managed Service for Prometheus workspace + managed collector.
#
# Uses the fully-managed AMP collector ("scraper") instead of a self-managed
# ADOT Collector deployment: AWS provisions, scales, and operates the scrape +
# remote-write pipeline directly against the EKS cluster's VPC, so there are no
# collector pods, IAM roles for service accounts, or Pod Identity associations
# to manage in-cluster. See _modules/amp.
#
# Full Terragrunt fragment included by <env>/<region>/amp/terragrunt.hcl. Env
# shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
}

terraform {
  source = "${get_repo_root()}//_modules/amp"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_arn               = "arn:aws:eks:${local.ctx.region}:000000000000:cluster/${local.ctx.name}"
    cluster_security_group_id = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
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
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  scrape_interval    = "30s"
  log_retention_days = 14

  workspace_alias               = local.ctx.name
  eks_cluster_arn               = dependency.eks.outputs.cluster_arn
  eks_cluster_security_group_id = dependency.eks.outputs.cluster_security_group_id
  subnet_ids                    = dependency.vpc.outputs.intra_subnets
}
