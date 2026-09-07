variable "bucket_name" {
  description = "Private S3 bucket name used for environment CDN assets."
  type        = string
}

variable "comment" {
  description = "CloudFront distribution comment."
  type        = string
}

variable "aliases" {
  description = "CloudFront alternate domain names."
  type        = list(string)
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
}

variable "is_ipv6_enabled" {
  description = "Whether IPv6 is enabled for CloudFront."
  type        = bool
}

variable "http_version" {
  description = "Maximum HTTP version supported by CloudFront."
  type        = string
}

variable "wait_for_deployment" {
  description = "Whether Terraform waits for CloudFront deployment."
  type        = bool
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the CDN alias."
  type        = string
}

variable "tags" {
  description = "Tags applied to the CDN bucket."
  type        = map(string)
  default     = {}
}