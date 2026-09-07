locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  project = local.project_vars.locals.project_name
  bucket  = "${local.project}-${local.env}-cdn"
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${get_repo_root()}/_modules/wordpress-s3-access"
}

inputs = {
  bucket_name = local.bucket
  bucket_arn  = "arn:aws:s3:::${local.bucket}"
  policy_name = "${local.project}-${local.env}-wordpress-s3-access"
}