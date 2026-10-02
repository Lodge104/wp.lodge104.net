output "web_acl_arn" {
  description = "ARN of the CloudFront-scoped WAF Web ACL."
  value       = aws_wafv2_web_acl.this.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch Logs log group receiving WAF logs."
  value       = aws_cloudwatch_log_group.waf.name
}
