variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "prod"
}

variable "zone_name" {
  description = "Delegated Route 53 zone name for this environment."
  type        = string
  default     = "prod.wp.lodge104.net"
}

variable "site_domain" {
  description = "WordPress site domain name."
  type        = string
  default     = "prod.wp.lodge104.net"
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name for the environment."
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID for alias records."
  type        = string
}

variable "db_endpoint" {
  description = "Aurora writer endpoint DNS name."
  type        = string
}

variable "db_reader_endpoint" {
  description = "Aurora reader endpoint DNS name."
  type        = string
}

variable "cache_endpoint" {
  description = "Cache endpoint DNS name."
  type        = string
}
