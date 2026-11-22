# -----------------------------------------------------------------------------
# env-promotion – Lambda + SSM document that copies WordPress data/uploads
# down the env chain (prod -> test -> dev) via the bastion host.
#
# Full Terragrunt fragment included by global/env-promotion/terragrunt.hcl.
# -----------------------------------------------------------------------------

locals {
  ctx       = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  wordpress = read_terragrunt_config("${get_repo_root()}/_common/shared/wordpress.hcl").locals
}

terraform {
  source = "${get_repo_root()}//_modules/env-promotion"
}

dependency "bastion" {
  config_path = "../bastion"

  mock_outputs = {
    instance_id = "i-00000000000000000"
    role_arn    = "arn:aws:iam::123456789012:role/${local.ctx.project}-bastion"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
}

inputs = {
  project_name = local.ctx.project
  region       = local.ctx.region
  domain       = local.ctx.domain

  bastion_instance_id = dependency.bastion.outputs.instance_id
  bastion_role_arn    = dependency.bastion.outputs.role_arn

  # The Helm release name and namespace are shared across every
  # environment's WordPress deployment.
  release_name        = local.wordpress.release_name
  wordpress_namespace = local.wordpress.namespace

  # Only "promote downward" is allowed: prod -> test, and test -> dev.
  # Add pairs here if other directions are ever needed.
  allowed_promotions = [
    { source = "prod", target = "test" },
    { source = "test", target = "dev" },
  ]
}
