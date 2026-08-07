locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/route53.hcl")
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env    = "prod"
  domain = local.project_vars.locals.domain
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

inputs = merge(
  local.common.locals,
  {
    create_zone   = true
    name          = "${local.env}.wp.${local.domain}"
    enable_dnssec = true
    records       = {}
  }
)
