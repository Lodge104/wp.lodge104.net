locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/bastion.hcl")
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  region      = local.region_vars.locals.aws_region
  project     = local.project_vars.locals.project_name
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${get_repo_root()}//_modules/bastion"
}

inputs = merge(
  local.common.locals,
  {
    project_name = local.project
    region       = local.region
  }
)
