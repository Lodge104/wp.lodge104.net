# Data sources to read parameters from AWS Systems Manager Parameter Store
# Use this file to read shared team configuration instead of local terraform.tfvars

# Read project configuration
data "aws_ssm_parameter" "project_name" {
  count = var.use_parameter_store ? 1 : 0
  name  = "/${var.project_name}/${var.environment}/project_name"
}

data "aws_ssm_parameter" "region" {
  count = var.use_parameter_store ? 1 : 0
  name  = "/${var.project_name}/${var.environment}/region"
}

data "aws_ssm_parameter" "domain_name" {
  count = var.use_parameter_store ? 1 : 0
  name  = "/${var.project_name}/${var.environment}/domain_name"
}

data "aws_ssm_parameter" "vpc_cidr" {
  count = var.use_parameter_store ? 1 : 0
  name  = "/${var.project_name}/${var.environment}/vpc_cidr"
}

# Read secure parameters
data "aws_ssm_parameter" "db_password" {
  count           = var.use_parameter_store ? 1 : 0
  name            = "/${var.project_name}/${var.environment}/db_password"
  with_decryption = true
}

data "aws_ssm_parameter" "redis_auth_token" {
  count           = var.use_parameter_store ? 1 : 0
  name            = "/${var.project_name}/${var.environment}/redis_auth_token"
  with_decryption = true
}

# Read CloudFront configuration
data "aws_ssm_parameter" "cloudfront_price_class" {
  count = var.use_parameter_store ? 1 : 0
  name  = "/${var.project_name}/${var.environment}/cloudfront_price_class"
}

data "aws_ssm_parameter" "cloudfront_default_ttl" {
  count = var.use_parameter_store ? 1 : 0
  name  = "/${var.project_name}/${var.environment}/cloudfront_default_ttl"
}

# Read instance configuration
data "aws_ssm_parameter" "instance_type" {
  count = var.use_parameter_store ? 1 : 0
  name  = "/${var.project_name}/${var.environment}/instance_type"
}

data "aws_ssm_parameter" "desired_capacity" {
  count = var.use_parameter_store ? 1 : 0
  name  = "/${var.project_name}/${var.environment}/desired_capacity"
}

# Local values that use Parameter Store data when enabled
locals {
  # Use Parameter Store values if enabled, otherwise use terraform.tfvars
  effective_project_name  = var.use_parameter_store ? data.aws_ssm_parameter.project_name[0].value : var.project_name
  effective_region        = var.use_parameter_store ? data.aws_ssm_parameter.region[0].value : var.region
  effective_domain_name   = var.use_parameter_store ? data.aws_ssm_parameter.domain_name[0].value : var.domain_name
  effective_vpc_cidr      = var.use_parameter_store ? data.aws_ssm_parameter.vpc_cidr[0].value : var.vpc_cidr
  effective_db_password   = var.use_parameter_store ? data.aws_ssm_parameter.db_password[0].value : var.db_password
  effective_redis_token   = var.use_parameter_store ? data.aws_ssm_parameter.redis_auth_token[0].value : var.redis_auth_token
  effective_cf_price      = var.use_parameter_store ? data.aws_ssm_parameter.cloudfront_price_class[0].value : var.cloudfront_price_class
  effective_cf_ttl        = var.use_parameter_store ? tonumber(data.aws_ssm_parameter.cloudfront_default_ttl[0].value) : var.cloudfront_default_ttl
  effective_instance_type = var.use_parameter_store ? data.aws_ssm_parameter.instance_type[0].value : var.instance_type
  effective_capacity      = var.use_parameter_store ? tonumber(data.aws_ssm_parameter.desired_capacity[0].value) : var.desired_capacity
}
