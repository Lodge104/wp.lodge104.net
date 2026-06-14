# Common CloudFront defaults – override in each env's terragrunt.hcl as needed.
locals {
  price_class = "PriceClass_100" # US, Canada, Europe

  is_ipv6_enabled     = true
  http_version        = "http2and3"
  wait_for_deployment = false

  # Default cache behaviour
  default_cache_behavior = {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400

    use_forwarded_values = true
    query_string         = false
    cookies_forward      = "none"
  }

  viewer_certificate = {
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  geo_restriction = {
    restriction_type = "none"
    locations        = []
  }
}
