output "lambda_function_name" {
  description = "Name of the WordPress deployer Lambda function"
  value       = aws_lambda_function.wordpress_deployer.function_name
}

output "lambda_function_arn" {
  description = "ARN of the WordPress deployer Lambda function"
  value       = aws_lambda_function.wordpress_deployer.arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the WordPress deployer Lambda function"
  value       = aws_lambda_function.wordpress_deployer.invoke_arn
}

output "efs_access_point_id" {
  description = "ID of the EFS access point for Lambda"
  value       = aws_efs_access_point.lambda.id
}

output "efs_access_point_arn" {
  description = "ARN of the EFS access point for Lambda"
  value       = aws_efs_access_point.lambda.arn
}
