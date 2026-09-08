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

variable "viewer_certificate" {
  description = "CloudFront viewer certificate configuration."
  type        = any
}

variable "origin" {
  description = "CloudFront origin configuration."
  type        = any
}

variable "default_cache_behavior" {
  description = "CloudFront default cache behavior."
  type        = any
}

variable "ordered_cache_behavior" {
  description = "CloudFront ordered cache behaviors."
  type        = any
  default     = []
}

variable "geo_restriction" {
  description = "CloudFront geo restriction configuration."
  type        = any
  default     = {}
}
