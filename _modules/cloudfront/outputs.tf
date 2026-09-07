output "cdn_bucket_name" {
  description = "CDN S3 bucket name."
  value       = aws_s3_bucket.cdn.bucket
}

output "cdn_bucket_arn" {
  description = "CDN S3 bucket ARN."
  value       = aws_s3_bucket.cdn.arn
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = module.cloudfront.cloudfront_distribution_arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = module.cloudfront.cloudfront_distribution_id
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name."
  value       = module.cloudfront.cloudfront_distribution_domain_name
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "CloudFront hosted zone ID."
  value       = module.cloudfront.cloudfront_distribution_hosted_zone_id
}