variable "name" {
  description = "Name of the CloudFront WAF Web ACL."
  type        = string
}

variable "login_rate_limit" {
  description = "Maximum login-style POST requests (wp-login.php, xmlrpc.php, /my-account) allowed per client IP within login_rate_window_seconds before that IP is blocked. Kept fairly high so many users behind one shared IP (e.g. a camp or event Wi-Fi) are not locked out."
  type        = number
  default     = 30

  validation {
    condition     = var.login_rate_limit >= 10
    error_message = "AWS WAF rate-based rules require a limit of at least 10."
  }
}

variable "login_rate_window_seconds" {
  description = "Evaluation window, in seconds, for the login rate limit. AWS WAF allows 60, 120, 300 or 600."
  type        = number
  default     = 300

  validation {
    condition     = contains([60, 120, 300, 600], var.login_rate_window_seconds)
    error_message = "login_rate_window_seconds must be one of 60, 120, 300 or 600."
  }
}

variable "log_retention_days" {
  description = "Retention period, in days, for the WAF CloudWatch Logs log group."
  type        = number
  default     = 30
}
