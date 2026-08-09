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

dependency "zone" {
  config_path = "${get_repo_root()}/global/route53-test"

  mock_outputs = {
    id = "Z2222222222222"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/acm/aws?version=5.1.1"
}

inputs = merge(
  local.common.locals,
  {
    domain_name               = "${local.env}.wp.${local.domain}"
    subject_alternative_names = ["*.${local.env}.wp.${local.domain}"]
    zone_id                   = dependency.zone.outputs.id
  }
)
