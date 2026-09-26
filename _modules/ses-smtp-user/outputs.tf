output "smtp_username" {
  description = "SES SMTP username (IAM access key ID)."
  value       = aws_iam_access_key.smtp.id
}

output "smtp_password" {
  description = "SES SMTP password, derived from the IAM secret access key using AWS's SigV4-based algorithm."
  value       = aws_iam_access_key.smtp.ses_smtp_password_v4
  sensitive   = true
}

output "smtp_credentials_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret holding the SMTP username and password."
  value       = aws_secretsmanager_secret.smtp_credentials.arn
}

output "access_key_id" {
  description = "SES IAM access key ID for Fluent Mail."
  value       = aws_iam_access_key.smtp.id
}

output "secret_access_key" {
  description = "SES IAM secret access key for Fluent Mail."
  value       = aws_iam_access_key.smtp.secret
  sensitive   = true
}
