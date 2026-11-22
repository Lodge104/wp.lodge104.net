# -----------------------------------------------------------------------------
# alb-security-group – restricts the WordPress ALB listener to CloudFront's
# origin-facing IP ranges so the origin can't be reached directly, bypassing
# CloudFront/any WAF in front of it.
#
# Full Terragrunt fragment included by <env>/<region>/alb-security-group/
# terragrunt.hcl. Env shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals

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

terraform {
  source = "tfr:///terraform-aws-modules/security-group/aws?version=6.0.0"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  name        = "${local.ctx.name}-alb-cloudfront-only"
  description = "WordPress ALB ingress restricted to CloudFront origin-facing IP ranges"
  vpc_id      = dependency.vpc.outputs.vpc_id

  ingress_rules = {
    https_from_cloudfront = {
      from_port      = 443
      to_port        = 443
      ip_protocol    = "tcp"
      description    = "HTTPS from CloudFront origin-facing IP ranges"
      prefix_list_id = local.cloudfront_origin_facing_prefix_list_id
    }
  }

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all outbound"
    }
  }
}
