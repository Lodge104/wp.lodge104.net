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
