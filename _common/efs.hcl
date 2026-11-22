# -----------------------------------------------------------------------------
# efs – EFS file system (+ CSI StorageClass) for WordPress persistent volumes.
#
# Full Terragrunt fragment included by <env>/<region>/efs/terragrunt.hcl. Env
# shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
}

terraform {
  source = "${get_repo_root()}//_modules/efs"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id          = "vpc-00000000000000000"
    private_subnets = ["subnet-00000000000000001", "subnet-00000000000000002", "subnet-00000000000000003"]
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name                       = local.ctx.name
    cluster_endpoint                   = "https://example.eks.amazonaws.com"
    cluster_certificate_authority_data = base64encode(file("${get_repo_root()}/_common/mock-ca.pem"))
    node_security_group_id             = "sg-00000000000000001"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  name       = local.ctx.name
  region     = local.ctx.region
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets

  eks_cluster_name                       = dependency.eks.outputs.cluster_name
  eks_cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  eks_cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  eks_node_security_group_id             = dependency.eks.outputs.node_security_group_id

  throughput_mode = "elastic"
}
