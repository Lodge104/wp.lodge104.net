locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/route53-prod-cutover.hcl")
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  domain = local.project_vars.locals.domain
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "cloudfront" {
  config_path = "${get_repo_root()}/prod/us-east-1/cloudfront"

  mock_outputs = {
    cloudfront_distribution_domain_name    = "d111111abcdef8.cloudfront.net"
    cloudfront_distribution_hosted_zone_id = "Z2FDTNDATAQYW2"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "cdn" {
  config_path = "${get_repo_root()}/prod/us-east-1/cdn"

  mock_outputs = {
    cloudfront_distribution_domain_name    = "d222222abcdef8.cloudfront.net"
    cloudfront_distribution_hosted_zone_id = "Z2FDTNDATAQYW2"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

inputs = merge(
  local.common.locals,
  {
    name = local.domain
    records = {
      root_ipv4 = {
        full_name = local.domain
        type = "A"
        alias = {
          name    = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      root_ipv6 = {
        full_name = local.domain
        type = "AAAA"
        alias = {
          name    = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      store_ipv4 = {
        full_name = "store.${local.domain}"
        type = "A"
        alias = {
          name    = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      store_ipv6 = {
        full_name = "store.${local.domain}"
        type = "AAAA"
        alias = {
          name    = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      cdn_ipv4 = {
        full_name = "cdn.${local.domain}"
        type = "A"
        alias = {
          name    = dependency.cdn.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cdn.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      cdn_ipv6 = {
        full_name = "cdn.${local.domain}"
        type = "AAAA"
        alias = {
          name    = dependency.cdn.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cdn.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
    }
  }
)