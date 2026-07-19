locals {
  common   = read_terragrunt_config("${get_repo_root()}/_common/acm.hcl")
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  env = local.env_vars.locals.env
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
    # Use a subdomain per environment; prod uses apex + wildcard only.
    domain_name               = "${local.env}.lodge104.net"
    subject_alternative_names = ["*.${local.env}.lodge104.net"]
  }
)
