locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/ses.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  region  = local.region_vars.locals.aws_region
  project = local.project_vars.locals.project_name
  domain  = local.project_vars.locals.domain
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${get_repo_root()}//_modules/ses-smtp-user"
}

inputs = {
  name        = "${local.common.locals.name}-${local.env}"
  domain      = local.domain
  region      = local.region
  secret_name = "${local.project}-${local.env}-ses-credentials"
}
