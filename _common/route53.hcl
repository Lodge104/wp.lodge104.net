# -----------------------------------------------------------------------------
# route53 – public records in the env's delegated zone <env>.wp.<domain>
# (managed by global/route53-<env>): site + store aliases to the WordPress
# CloudFront distribution, cdn. alias to the uploads CDN, and the origin.
# alias to the WordPress ALB that CloudFront connects to.
#
# Apex-domain records (lodge104.net, www., store., cdn.) are NOT managed here
# -- they belong to the parent zone and live in global/route53-prod-cutover.
# (A record with full_name = "www.<domain>" in this module would be created
# as "www.<domain>.prod.wp.<domain>".)
#
# Full Terragrunt fragment included by <env>/<region>/route53/terragrunt.hcl.
# Env shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx    = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  shared = read_terragrunt_config("${get_repo_root()}/_common/shared/route53.hcl").locals
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

dependency "cloudfront" {
  config_path = "../cloudfront"

  mock_outputs = {
    cloudfront_distribution_domain_name    = "d111111abcdef8.cloudfront.net"
    cloudfront_distribution_hosted_zone_id = "Z2FDTNDATAQYW2"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  # During `run -a destroy`, cloudfront may already be torn down by the time
  # its outputs are read here, leaving them empty; fall back to mocks.
  mock_outputs_merge_strategy_with_state = "shallow"
}

dependency "cdn" {
  config_path = "../cdn"

  mock_outputs = {
    cloudfront_distribution_domain_name    = "d111111abcdef8.cloudfront.net"
    cloudfront_distribution_hosted_zone_id = "Z2FDTNDATAQYW2"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "wordpress" {
  config_path = "../wordpress"

  mock_outputs = {
    ingress_hostname = "mock-alb-123456789.${local.ctx.region}.elb.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# Ordering only: the env's delegated zone must exist before records go in.
dependency "zone" {
  config_path  = "${get_repo_root()}/global/route53-${local.ctx.env}"
  skip_outputs = true
}

inputs = merge(
  local.shared,
  {
    name = local.ctx.env_domain
    records = {
      cloudfront_ipv4 = {
        full_name = local.ctx.env_domain
        type      = "A"
        alias = {
          name    = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      cloudfront_ipv6 = {
        full_name = local.ctx.env_domain
        type      = "AAAA"
        alias = {
          name    = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      # Multisite "store" site, served by the same CloudFront distribution.
      store_cloudfront_ipv4 = {
        full_name = "store.${local.ctx.env_domain}"
        type      = "A"
        alias = {
          name    = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      store_cloudfront_ipv6 = {
        full_name = "store.${local.ctx.env_domain}"
        type      = "AAAA"
        alias = {
          name    = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      cdn_ipv4 = {
        full_name = "cdn.${local.ctx.env_domain}"
        type      = "A"
        alias = {
          name    = dependency.cdn.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cdn.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      cdn_ipv6 = {
        full_name = "cdn.${local.ctx.env_domain}"
        type      = "AAAA"
        alias = {
          name    = dependency.cdn.outputs.cloudfront_distribution_domain_name
          zone_id = dependency.cdn.outputs.cloudfront_distribution_hosted_zone_id
        }
      }
      # CloudFront origin domain – lets CloudFront connect to the ALB over
      # HTTPS using a hostname covered by the *.<env>.wp.<domain> ACM cert
      # instead of the ALB's own auto-generated domain (which the cert
      # doesn't cover, causing TLS handshake failures / 502s from
      # CloudFront).
      origin_alb = {
        name = "origin"
        type = "A"
        alias = {
          name    = dependency.wordpress.outputs.ingress_hostname
          zone_id = local.ctx.alb_hosted_zone_id
        }
      }
    }
  }
)
