# CloudFront Distribution
resource "aws_cloudfront_distribution" "wordpress" {
  aliases = var.domain_name != "" ? [var.domain_name, "www.${var.domain_name}", "*.${var.domain_name}"] : []

  origin {
    domain_name = var.alb_domain_name
    origin_id   = "${var.project_name}-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = var.origin_protocol_policy
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.project_name}"
  default_root_object = "index.php"

  # Cache behavior for WordPress admin
  ordered_cache_behavior {
    path_pattern     = "/wp-admin/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.project_name}-alb-origin"

    forwarded_values {
      query_string = var.query_string
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = var.admin_ttl
    default_ttl            = var.admin_ttl
    max_ttl                = var.admin_ttl
    compress               = false
  }

  # Cache behavior for WordPress login
  ordered_cache_behavior {
    path_pattern     = "/wp-login.php"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.project_name}-alb-origin"

    forwarded_values {
      query_string = var.query_string
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = var.admin_ttl
    default_ttl            = var.admin_ttl
    max_ttl                = var.admin_ttl
    compress               = false
  }

  # Cache behavior for static assets (CSS)
  ordered_cache_behavior {
    path_pattern     = "*.css"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.project_name}-alb-origin"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = var.min_ttl
    default_ttl            = var.max_ttl # Cache CSS for maximum time
    max_ttl                = var.max_ttl
    compress               = var.compress
  }

  # Cache behavior for static assets (JS)
  ordered_cache_behavior {
    path_pattern     = "*.js"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.project_name}-alb-origin"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = var.min_ttl
    default_ttl            = var.max_ttl # Cache JS for maximum time
    max_ttl                = var.max_ttl
    compress               = var.compress
  }

  # Cache behavior for images and uploads
  ordered_cache_behavior {
    path_pattern     = "/wp-content/uploads/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.project_name}-alb-origin"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = var.min_ttl
    default_ttl            = var.max_ttl # Cache uploads for maximum time
    max_ttl                = var.max_ttl
    compress               = var.compress
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${var.project_name}-alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = var.query_string
      headers      = ["Host", "CloudFront-Forwarded-Proto"]

      cookies {
        forward           = var.cookies_forward
        whitelisted_names = var.cookies_forward == "whitelist" ? ["comment_*", "wordpress_*", "wp-*"] : []
      }
    }

    min_ttl     = var.min_ttl
    default_ttl = var.default_ttl
    max_ttl     = var.max_ttl
    compress    = var.compress
  }

  price_class = var.price_class

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.ssl_certificate_arn == "" ? true : false
    acm_certificate_arn            = var.ssl_certificate_arn != "" ? var.ssl_certificate_arn : null
    ssl_support_method             = var.ssl_certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.ssl_certificate_arn != "" ? "TLSv1.2_2021" : null
  }

  tags = {
    Name        = "${var.project_name}-cloudfront"
    Environment = var.environment
  }
}