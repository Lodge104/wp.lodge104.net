locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/route53.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env            = local.env_vars.locals.env
  region         = local.region_vars.locals.aws_region
  domain         = local.project_vars.locals.domain
  alb_zone_id    = local.region_vars.locals.alb_hosted_zone_id
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "cloudfront" {
  config_path = "../cloudfront"

  mock_outputs = {
    cloudfront_distribution_domain_name    = "d111111abcdef8.cloudfront.net"
    cloudfront_distribution_hosted_zone_id = "Z2FDTNDATAQYW2"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "wordpress" {
  config_path = "../wordpress"

  mock_outputs = {
    ingress_hostname = "mock-alb-123456789.${local.region}.elb.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

inputs = merge(
  local.common.locals,
  {
    zone_id = "Z02518842QX1X2K88785A"
    records = {
      cloudfront_ipv4 = {
        name = local.env
        type = "A"
        alias = {
          name    = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      cloudfront_ipv6 = {
        name = local.env
        type = "AAAA"
        alias = {
          name    = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      # CloudFront origin domain – lets CloudFront connect to the ALB over
      # HTTPS using a hostname covered by the *.${local.domain} ACM cert
      # instead of the ALB's own auto-generated domain (which the cert
      # doesn't cover, causing TLS handshake failures / 502s from CloudFront).
      origin_alb = {
        name = "origin.${local.env}"
        type = "A"
        alias = {
          name    = dependency.wordpress.outputs.ingress_hostname
          zone_id = local.alb_zone_id
        }
      }
    }
  }
)
