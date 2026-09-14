variable "bucket_name" {
  description = "S3 bucket receiving CloudFront requests."
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket receiving CloudFront requests."
  type        = string
}
