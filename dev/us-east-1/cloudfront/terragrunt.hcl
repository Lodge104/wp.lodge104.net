locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/cloudfront.hcl")
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
  source = "tfr:///terraform-aws-modules/cloudfront/aws?version=3.4.1"
}

inputs = merge(
  local.common.locals,
  {
    comment = "${local.project} ${local.env} distribution"
    # Multisite "store" site shares this distribution/origin.
    aliases = ["${local.env}.wp.${local.domain}", "store.${local.env}.wp.${local.domain}"]

    viewer_certificate = {
      acm_certificate_arn      = dependency.acm.outputs.acm_certificate_arn
      minimum_protocol_version = "TLSv1.2_2021"
      ssl_support_method       = "sni-only"
    }

    origin = {
      alb = {
        # A DNS alias to the ALB, covered by the *.${local.env}.wp.${local.domain} ACM
        # wildcard cert (see route53/terragrunt.hcl) – CloudFront's HTTPS
        # handshake to a custom origin validates the cert against the
        # origin domain name, which the ALB's own auto-generated hostname
        # is never covered by.
        domain_name = "origin.${local.env}.wp.${local.domain}"
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
