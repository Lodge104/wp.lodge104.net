variable "name" {
  description = "Name for the IAM user used as the SES SMTP sender."
  type        = string
}

variable "domain" {
  description = "Verified SES domain identity to scope the IAM user's sending permission to (e.g. lodge104.net)."
  type        = string
}

variable "region" {
  description = "AWS region the SES domain identity was verified in."
  type        = string
}

variable "secret_name" {
  description = "Name of the AWS Secrets Manager secret to store the generated SMTP username and password in."
  type        = string
}

variable "secret_recovery_window_in_days" {
  description = "Number of days AWS Secrets Manager waits before permanently deleting the SMTP credentials secret after destruction. Set to 0 to delete immediately (useful for ephemeral/dev environments)."
  type        = number
  default     = 0

  validation {
    condition     = var.secret_recovery_window_in_days == 0 || (var.secret_recovery_window_in_days >= 7 && var.secret_recovery_window_in_days <= 30)
    error_message = "secret_recovery_window_in_days must be 0 or an integer from 7 through 30."
  }
}
