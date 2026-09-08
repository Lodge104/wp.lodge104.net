terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
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
  ordered_cache_behavior = var.ordered_cache_behavior
  viewer_certificate     = var.viewer_certificate
  geo_restriction        = var.geo_restriction
}
