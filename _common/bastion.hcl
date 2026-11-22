# -----------------------------------------------------------------------------
# bastion – single SSM-only Graviton host for operational access (EFS/S3
# transfers, wp-cli via env-promotion), placed in the "home" env VPC.
#
# Full Terragrunt fragment included by global/bastion/terragrunt.hcl.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  eks = read_terragrunt_config("${get_repo_root()}/_common/shared/eks.hcl").locals
}

terraform {
  source = "${get_repo_root()}//_modules/bastion"
}

inputs = {
  project_name = local.ctx.project
  region       = local.ctx.region

  # kubectl on the host matches the clusters' Kubernetes version.
  kubernetes_version = local.eks.kubernetes_version

  environment_names = ["dev", "test", "prod"]

  # Prefer running the bastion in prod when it exists, then test, then dev.
  bastion_home_env_preference = ["prod", "test", "dev"]

  # Graviton -- cheaper per-hour than the x86 t3 family for this SSM-only,
  # low-utilization host. See issue #32.
  instance_type = "t4g.small"

  # Keep this tiny because the host is SSM-only and for operational access.
  root_volume_size = 20

  transfer_bucket_name = "lodge104-transfer-1"

  tags = {
    Component = "bastion"
    ManagedBy = "terraform"
  }
}
