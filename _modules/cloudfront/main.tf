terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "cdn" {
  bucket        = var.bucket_name
  force_destroy = false

  tags = merge(var.tags, {
    Name = var.bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "cdn" {
  statement {
    sid    = "AllowCloudFrontReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cdn.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront.cloudfront_distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cdn" {
  bucket = aws_s3_bucket.cdn.id
  policy = data.aws_iam_policy_document.cdn.json

  depends_on = [aws_s3_bucket_public_access_block.cdn]
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

  create_origin_access_control = true
  origin_access_control = {
    cdn = {
      description      = "CloudFront access to ${var.bucket_name}"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    cdn = {
      domain_name           = aws_s3_bucket.cdn.bucket_regional_domain_name
      origin_access_control = "cdn"
    }
  }

  default_cache_behavior = {
    target_origin_id       = "cdn"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true
    query_string           = false
    cookies_forward        = "none"
  }

  viewer_certificate = {
    acm_certificate_arn      = var.acm_certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  geo_restriction = {
    restriction_type = "none"
    locations        = []
  }
}