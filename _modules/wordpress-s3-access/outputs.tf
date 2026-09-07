output "policy_arn" {
  description = "ARN of the WP Offload Media IAM policy."
  value       = aws_iam_policy.this.arn
}