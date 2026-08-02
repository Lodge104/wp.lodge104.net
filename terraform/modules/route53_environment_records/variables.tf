variable "zone_name" {
  description = "Delegated public Route 53 zone name for the environment."
  type        = string
}

variable "site_domain" {
  description = "Public site domain name served by CloudFront."
  type        = string
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID for Route 53 alias records."
  type        = string
}

variable "db_endpoint" {
  description = "Database writer endpoint DNS name."
  type        = string
}

variable "db_reader_endpoint" {
  description = "Database reader endpoint DNS name."
  type        = string
}

variable "cache_endpoint" {
  description = "Cache endpoint DNS name."
  type        = string
}
