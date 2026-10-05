variable "name" {
  description = "Name of the CloudFront WAF Web ACL."
  type        = string
}

variable "log_retention_days" {
  description = "Retention period, in days, for the WAF CloudWatch Logs log group."
  type        = number
  default     = 30
}
