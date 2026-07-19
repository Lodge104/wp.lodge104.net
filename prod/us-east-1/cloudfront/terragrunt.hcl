locals {
  common   = read_terragrunt_config("${get_repo_root()}/_common/cloudfront.hcl")
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  env = local.env_vars.locals.env
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "acm" {
  config_path = "../acm"

  mock_outputs = {
    acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "wordpress" {
  config_path = "../wordpress"

  mock_outputs = {
    ingress_hostname = "mock-alb-123456789.us-east-1.elb.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

terraform {
  source = "tfr:///terraform-aws-modules/cloudfront/aws?version=3.4.1"
}

inputs = merge(
  local.common.locals,
  {
    comment = "lodge104 ${local.env} distribution"

    aliases = ["lodge104.net", "www.lodge104.net"]

    # Prod: all edge locations for lowest latency globally
    price_class = "PriceClass_All"

    viewer_certificate = {
      acm_certificate_arn      = dependency.acm.outputs.acm_certificate_arn
      minimum_protocol_version = "TLSv1.2_2021"
      ssl_support_method       = "sni-only"
    }

    origin = {
      alb = {
        domain_name = dependency.wordpress.outputs.ingress_hostname
        custom_origin_config = {
          http_port              = 80
          https_port             = 443
          origin_protocol_policy = "https-only"
          origin_ssl_protocols   = ["TLSv1.2"]
        }
      }
    }

    default_cache_behavior = merge(
      local.common.locals.default_cache_behavior,
      {
        target_origin_id = "alb"
      }
    )
  }
)
