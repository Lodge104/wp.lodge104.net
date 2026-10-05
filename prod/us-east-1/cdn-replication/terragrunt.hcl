locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  project = local.project_vars.locals.project_name
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "cdn" {
  config_path = "../cdn"

  mock_outputs = {
    cdn_bucket_name = "${local.project}-${local.env}-cdn"
    cdn_bucket_arn  = "arn:aws:s3:::${local.project}-${local.env}-cdn"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${get_repo_root()}/_modules/s3-replication"
}

inputs = {
  source_bucket_name = dependency.cdn.outputs.cdn_bucket_name
  source_bucket_arn  = dependency.cdn.outputs.cdn_bucket_arn

  # Archive copy lives in a separate Region from every other resource in
  # this project (us-east-1) -- a deliberate blast-radius/DR choice, not a
  # mistake, so it's hardcoded here rather than read from region.hcl.
  destination_bucket_name = "${local.project}-${local.env}-cdn-archive"
  destination_region      = "us-west-2"

  replication_role_name = "${local.project}-${local.env}-cdn-replication"
  replication_rule_id   = "${local.env}-cdn-archive-deep-archive"
}
