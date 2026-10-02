locals {
  wordpress_common = read_terragrunt_config("${get_repo_root()}/_common/wordpress.hcl")
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars     = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  region  = local.region_vars.locals.aws_region
  project = local.project_vars.locals.project_name
  domain  = local.project_vars.locals.domain
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "bastion" {
  config_path = "../bastion"

  mock_outputs = {
    enabled     = true
    instance_id = "i-00000000000000000"
    role_arn    = "arn:aws:iam::123456789012:role/${local.project}-bastion"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${get_repo_root()}//_modules/env-promotion"
}

inputs = {
  project_name = local.project
  region       = local.region
  domain       = local.domain

  bastion_instance_id = dependency.bastion.outputs.instance_id
  bastion_role_arn    = dependency.bastion.outputs.role_arn

  # Matches _common/wordpress.hcl -- the Helm release name and namespace
  # are shared across every environment's WordPress deployment.
  release_name        = local.wordpress_common.locals.release_name
  wordpress_namespace = local.wordpress_common.locals.namespace

  # Only "promote downward" is allowed: prod -> test, and test -> dev.
  # Add pairs here if other directions are ever needed.
  allowed_promotions = [
    { source = "prod", target = "test" },
    { source = "test", target = "dev" },
  ]
}
