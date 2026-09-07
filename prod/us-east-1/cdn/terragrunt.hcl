locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/cdn.hcl")
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

dependency "acm" {
  config_path = "../acm"

  mock_outputs = {
    acm_certificate_arn = "arn:aws:acm:${local.region}:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${get_repo_root()}/_modules/cloudfront"
}

inputs = merge(
  local.common.locals,
  {
  bucket_name         = "${local.project}-${local.env}-cdn"
  comment             = "${local.project} ${local.env} uploads CDN"
  aliases             = ["cdn.${local.env}.wp.${local.domain}"]
  acm_certificate_arn = dependency.acm.outputs.acm_certificate_arn
  price_class         = "PriceClass_All"
  origin_access_control_name = "cdn-${local.env}"
  }
)