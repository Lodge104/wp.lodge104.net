variable "bucket_name" {
  description = "S3 bucket name used by WP Offload Media."
  type        = string
}

variable "bucket_arn" {
  description = "S3 bucket ARN used by WP Offload Media."
  type        = string
}

variable "policy_name" {
  description = "IAM policy name."
  type        = string
}