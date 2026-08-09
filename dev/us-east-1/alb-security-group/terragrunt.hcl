locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/alb-security-group.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  project = local.project_vars.locals.project_name

  # CloudFront's global "origin-facing" managed prefix list ID is
  # account/partition-specific, so resolve it via the AWS CLI at plan time
  # rather than hardcoding it.
  cloudfront_origin_facing_prefix_list_id = run_cmd(
    "--terragrunt-quiet",
    "aws", "ec2", "describe-managed-prefix-lists",
    "--filters", "Name=prefix-list-name,Values=com.amazonaws.global.cloudfront.origin-facing",
    "--query", "PrefixLists[0].PrefixListId",
    "--output", "text"
  )
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/security-group/aws?version=6.0.0"
}

inputs = merge(
  local.common.locals,
  {
    name        = "${local.project}-${local.env}-alb-cloudfront-only"
    description = "WordPress ALB ingress restricted to CloudFront origin-facing IP ranges"
    vpc_id      = dependency.vpc.outputs.vpc_id

    ingress_rules = {
      https_from_cloudfront = merge(
        local.common.locals.ingress_rules.https_from_cloudfront,
        { prefix_list_id = local.cloudfront_origin_facing_prefix_list_id }
      )
    }
  }
)
