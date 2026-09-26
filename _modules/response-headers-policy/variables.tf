variable "name" {
  description = "Unique CloudFront response headers policy name. Names are account-global."
  type        = string
}

variable "cache_control_value" {
  description = "Cache-Control header value forced onto every response using this policy."
  type        = string
  default     = "public, max-age=31536000, immutable"
}
