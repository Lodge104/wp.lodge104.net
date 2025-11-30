# Main Terraform configuration for WordPress infrastructure on Elastic Beanstalk

module "vpc" {
  source = "./modules/vpc"

  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  allowed_ip_ranges = ["0.0.0.0/0"]
}

module "efs" {
  source = "./modules/efs"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.security.efs_security_group_id
}

# module "elasticache" {
#   source = "./modules/elasticache"
#   
#   project_name       = var.project_name
#   environment       = "prod"
#   subnet_ids        = module.vpc.database_subnet_ids
#   security_group_ids = [module.security.redis_security_group_id]
#   node_type         = var.redis_node_type
#   num_cache_clusters = var.redis_num_cache_clusters
#   auth_token        = var.redis_auth_token
#   auth_token_enabled = var.redis_auth_token != ""
# }

module "rds" {
  source                   = "./modules/rds"
  cluster_identifier       = "lodge104-${var.environment}-aurora"
  username                 = var.db_username
  password                 = var.db_password
  security_group_id        = module.security.database_security_group_id
  db_subnet_ids            = module.vpc.database_subnet_ids
  backup_retention_period  = var.backup_retention_period
  backup_window            = var.backup_window
  maintenance_window       = var.maintenance_window
  auto_pause               = var.auto_pause
  max_capacity             = var.max_capacity
  min_capacity             = var.min_capacity
  seconds_until_auto_pause = var.seconds_until_auto_pause
  project_name             = var.project_name
  environment              = var.environment
}

module "acm" {
  source = "./modules/acm"

  project_name    = var.project_name
  environment     = var.environment
  domain_name     = var.domain_name
  route53_zone_id = var.route53_zone_id
}

# Elastic Beanstalk module for WordPress with PHP 8.4
# Note: Elastic Beanstalk creates its own Application Load Balancer
module "elasticbeanstalk" {
  source = "./modules/elasticbeanstalk"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  security_group_ids  = [module.security.web_server_security_group_id]
  instance_type       = var.instance_type
  min_size            = var.min_size
  max_size            = var.max_size
  efs_file_system_id  = module.efs.file_system_id
  db_endpoint         = module.rds.cluster_endpoint
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  redis_endpoint      = "" # ElastiCache temporarily disabled
  redis_port          = "6379"
  redis_auth_token    = ""
  redis_auth_enabled  = false
  primary_domain      = var.domain_name
  ssl_certificate_arn = module.acm.certificate_arn
  enable_https        = var.domain_name != "" ? true : false
  key_name            = var.key_name

  # PHP 8.3 is currently the latest stable version on Amazon Linux 2023
  # PHP 8.4 will be used when AWS releases the solution stack
  solution_stack_name = var.eb_solution_stack_name
}

module "cloudfront" {
  source = "./modules/cloudfront"

  domain_name         = var.domain_name
  alb_domain_name     = module.elasticbeanstalk.endpoint_url
  ssl_certificate_arn = module.acm.certificate_arn
  environment         = var.environment

  # Caching configuration
  price_class     = var.cloudfront_price_class
  default_ttl     = var.cloudfront_default_ttl
  max_ttl         = var.cloudfront_max_ttl
  min_ttl         = var.cloudfront_min_ttl
  admin_ttl       = var.cloudfront_admin_ttl
  compress        = var.cloudfront_compress
  query_string    = var.cloudfront_query_string
  cookies_forward = var.cloudfront_cookies_forward
}

module "route53" {
  source = "./modules/route53"

  project_name           = var.project_name
  environment            = var.environment
  domain_name            = var.domain_name
  create_hosted_zone     = false
  existing_zone_id       = var.route53_zone_id
  cloudfront_domain_name = module.cloudfront.cloudfront_domain_name
  cloudfront_zone_id     = module.cloudfront.cloudfront_hosted_zone_id
}
