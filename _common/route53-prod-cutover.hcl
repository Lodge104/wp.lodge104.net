# -----------------------------------------------------------------------------
# route53-prod-cutover – apex-domain records in the existing <domain> public
# zone (project.hcl parent_zone_id): the apex, store. and www. point at prod's
# WordPress CloudFront distribution, cdn. at prod's uploads CDN. Delegated
# per-env zones remain separate.
#
# Full Terragrunt fragment included by global/route53-prod-cutover/
# terragrunt.hcl.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals

  # Hostname -> record key prefix, per target distribution. Each gets an A
  # and an AAAA alias (<key>_ipv4 / <key>_ipv6).
  #   www. is 301-redirected to the apex by WordPress
  #   (wordpressExtraConfigContent). It was once (incorrectly) defined in
  #   prod/us-east-1/route53 with full_name = "www.<domain>", but that module
  #   is scoped to the prod.wp.<domain> delegated zone, so it created a
  #   useless "www.<domain>.prod.wp.<domain>" record instead.
  cloudfront_hosts = {
    root  = local.ctx.domain
    store = "store.${local.ctx.domain}"
    www   = "www.${local.ctx.domain}"
  }
  cdn_hosts = {
    cdn = "cdn.${local.ctx.domain}"
  }
  record_types = { ipv4 = "A", ipv6 = "AAAA" }
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

dependency "cloudfront" {
  config_path = "${get_repo_root()}/prod/us-east-1/cloudfront"

  mock_outputs = {
    cloudfront_distribution_domain_name    = "d111111abcdef8.cloudfront.net"
    cloudfront_distribution_hosted_zone_id = "Z2FDTNDATAQYW2"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
}

dependency "cdn" {
  config_path = "${get_repo_root()}/prod/us-east-1/cdn"

  mock_outputs = {
    cloudfront_distribution_domain_name    = "d222222abcdef8.cloudfront.net"
    cloudfront_distribution_hosted_zone_id = "Z2FDTNDATAQYW2"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
}

inputs = {
  # Existing zone -- this stack manages records only.
  create_zone = false
  zone_id     = local.ctx.parent_zone_id
  name        = local.ctx.domain

  records = merge(
    merge([
      for key, host in local.cloudfront_hosts : {
        for suffix, type in local.record_types : "${key}_${suffix}" => {
          full_name = host
          type      = type
          alias = {
            name    = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
            zone_id = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
          }
        }
      }
    ]...),
    merge([
      for key, host in local.cdn_hosts : {
        for suffix, type in local.record_types : "${key}_${suffix}" => {
          full_name = host
          type      = type
          alias = {
            name    = dependency.cdn.outputs.cloudfront_distribution_domain_name
            zone_id = dependency.cdn.outputs.cloudfront_distribution_hosted_zone_id
          }
        }
      }
    ]...),
  )
}
