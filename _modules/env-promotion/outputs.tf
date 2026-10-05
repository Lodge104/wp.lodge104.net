output "function_name" {
  description = "Name of the promotion Lambda function."
  value       = aws_lambda_function.promote.function_name
}

output "function_arn" {
  description = "ARN of the promotion Lambda function."
  value       = aws_lambda_function.promote.arn
}

output "ssm_document_name" {
  description = "Name of the SSM Command document executed on the bastion."
  value       = aws_ssm_document.promote.name
}

output "ssm_command_log_group" {
  description = "CloudWatch Logs group that streams SSM command stdout/stderr."
  value       = aws_cloudwatch_log_group.ssm_command.name
}
