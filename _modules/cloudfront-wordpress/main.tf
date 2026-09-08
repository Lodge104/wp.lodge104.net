terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Static WordPress assets (uploads/themes/plugins/wp-includes) are
# content-addressed and never change, so force a long-lived, immutable
# Cache-Control on those responses regardless of what the origin sends.
resource "aws_cloudfront_response_headers_policy" "static_assets" {
  name = "${replace(var.comment, " ", "-")}-static-assets-cache"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "public, max-age=31536000, immutable"
      override = true
    }
  }
}

locals {
  # Behaviors with a long max_ttl are the static-asset ones (see
  # wordpress_static_asset_behavior in _common/cloudfront.hcl); the
  # always-dynamic no-cache behaviors (max_ttl = 0) are left untouched.
  ordered_cache_behavior = [
    for behavior in var.ordered_cache_behavior : merge(
      behavior,
      lookup(behavior, "max_ttl", 0) >= 86400 ? {
        response_headers_policy_id = aws_cloudfront_response_headers_policy.static_assets.id
      } : {}
    )
  ]
}

module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "3.4.1"

  comment             = var.comment
  aliases             = var.aliases
  price_class         = var.price_class
  is_ipv6_enabled     = var.is_ipv6_enabled
  http_version        = var.http_version
  wait_for_deployment = var.wait_for_deployment

  origin                 = var.origin
  default_cache_behavior = var.default_cache_behavior
  ordered_cache_behavior = local.ordered_cache_behavior
  viewer_certificate     = var.viewer_certificate
  geo_restriction        = var.geo_restriction
}
