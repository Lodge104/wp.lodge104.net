variable "bucket_name" {
  description = "Name of the S3 bucket that receives CloudFront standard access logs."
  type        = string
}

variable "retention_days" {
  description = "Days to keep log objects before they expire. Matches the 30-day WAF log retention by default."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_days >= 1
    error_message = "retention_days must be at least 1."
  }
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket even if it still contains log objects. Logs are disposable, but leave false in production."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the log bucket."
  type        = map(string)
  default     = {}
}
