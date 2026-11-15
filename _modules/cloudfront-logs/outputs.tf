output "bucket_name" {
  description = "Name of the CloudFront access log bucket."
  value       = aws_s3_bucket.logs.id
}

output "bucket_domain_name" {
  description = "S3 domain name to use as logging_config.bucket on the CloudFront distribution (<bucket>.s3.amazonaws.com)."
  value       = aws_s3_bucket.logs.bucket_domain_name
}
