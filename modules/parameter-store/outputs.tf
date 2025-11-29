output "parameter_arns" {
  description = "ARNs of all created parameters"
  value = {
    project_name           = aws_ssm_parameter.project_name.arn
    region                 = aws_ssm_parameter.region.arn
    domain_name            = var.domain_name != "" ? aws_ssm_parameter.domain_name[0].arn : ""
    vpc_cidr               = aws_ssm_parameter.vpc_cidr.arn
    db_password            = aws_ssm_parameter.db_password.arn
    redis_auth_token       = var.redis_auth_token != "" ? aws_ssm_parameter.redis_auth_token[0].arn : ""
    cloudfront_price_class = aws_ssm_parameter.cloudfront_price_class.arn
    cloudfront_default_ttl = aws_ssm_parameter.cloudfront_default_ttl.arn
    instance_type          = aws_ssm_parameter.instance_type.arn
    desired_capacity       = aws_ssm_parameter.desired_capacity.arn
  }
}

output "parameter_names" {
  description = "Names of all created parameters"
  value = {
    project_name           = aws_ssm_parameter.project_name.name
    region                 = aws_ssm_parameter.region.name
    domain_name            = var.domain_name != "" ? aws_ssm_parameter.domain_name[0].name : ""
    vpc_cidr               = aws_ssm_parameter.vpc_cidr.name
    db_password            = aws_ssm_parameter.db_password.name
    redis_auth_token       = var.redis_auth_token != "" ? aws_ssm_parameter.redis_auth_token[0].name : ""
    cloudfront_price_class = aws_ssm_parameter.cloudfront_price_class.name
    cloudfront_default_ttl = aws_ssm_parameter.cloudfront_default_ttl.name
    instance_type          = aws_ssm_parameter.instance_type.name
    desired_capacity       = aws_ssm_parameter.desired_capacity.name
  }
}
