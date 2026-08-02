locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/acm.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  domain  = local.project_vars.locals.domain
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "tfr:///terraform-aws-modules/acm/aws?version=5.1.1"
}

inputs = merge(
  local.common.locals,
  {
    domain_name = local.domain
    subject_alternative_names = [
      "*.${local.domain}",
      "www.${local.domain}",
    ]
  }
)
