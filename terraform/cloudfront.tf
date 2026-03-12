# ── Cache Policies ────────────────────────────────────────────────────────────────

# Use the AWS-managed CachingDisabled policy for dynamic WordPress content
# (admin, REST API, checkout, etc.). Custom TTL=0 policies are invalid in CloudFront.
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# Static assets — long TTL, no cookies or query strings in cache key.
resource "aws_cloudfront_cache_policy" "static" {
  name        = "${var.environment}-wordpress-static"
  comment     = "Long-TTL cache policy for WordPress static assets"
  min_ttl     = 0
  default_ttl = 86400    # 1 day
  max_ttl     = 31536000 # 1 year

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# ── Origin Request Policy ─────────────────────────────────────────────────────────
# Forward all viewer headers and cookies to the origin (ALB).

resource "aws_cloudfront_origin_request_policy" "alb" {
  name    = "${var.environment}-wordpress-alb-origin"
  comment = "Forward all viewer request data to ALB origin"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewer"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# ── Distribution ──────────────────────────────────────────────────────────────────

resource "aws_cloudfront_distribution" "wordpress" {
  aliases         = [var.site_domain]
  comment         = "${var.site_domain} WordPress (${var.environment})"
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_100" # US, Canada, Europe — adjust if needed

  # ALB origin. CloudFront injects a secret header so the ALB can reject
  # requests that bypass CloudFront.
  origin {
    domain_name = aws_lb.wordpress.dns_name
    origin_id   = "alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 60
      origin_keepalive_timeout = 60
    }

    custom_header {
      name  = "X-CloudFront-Secret"
      value = random_password.cf_secret.result
    }
  }

  # Default behavior — all dynamic WordPress traffic (uncached).
  default_cache_behavior {
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.alb.id
  }

  # Cache uploaded media files for a long time.
  ordered_cache_behavior {
    path_pattern             = "/wp-content/uploads/*"
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = aws_cloudfront_cache_policy.static.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.alb.id
  }

  # Cache WordPress core static files (themes, plugins, JS, CSS).
  ordered_cache_behavior {
    path_pattern             = "/wp-includes/*"
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = aws_cloudfront_cache_policy.static.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.alb.id
  }

  # Cache theme/plugin CSS and JS.
  ordered_cache_behavior {
    path_pattern             = "/wp-content/themes/*"
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = aws_cloudfront_cache_policy.static.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.alb.id
  }

  ordered_cache_behavior {
    path_pattern             = "/wp-content/plugins/*"
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = aws_cloudfront_cache_policy.static.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.alb.id
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.wordpress.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = { Name = "${var.environment}-wordpress-cf" }
}
