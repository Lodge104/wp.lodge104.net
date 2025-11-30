# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

# Elastic Beanstalk Outputs
output "eb_application_name" {
  description = "Name of the Elastic Beanstalk application"
  value       = module.elasticbeanstalk.application_name
}

output "eb_environment_name" {
  description = "Name of the Elastic Beanstalk environment"
  value       = module.elasticbeanstalk.environment_name
}

output "eb_endpoint_url" {
  description = "CNAME of the Elastic Beanstalk environment"
  value       = module.elasticbeanstalk.endpoint_url
}

output "eb_load_balancer_url" {
  description = "Load balancer URL for the Elastic Beanstalk environment"
  value       = module.elasticbeanstalk.load_balancer_url
}

# CloudFront Outputs
output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.cloudfront.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.cloudfront.cloudfront_distribution_id
}

# RDS Aurora Serverless Outputs
output "aurora_cluster_endpoint" {
  description = "Aurora Serverless cluster endpoint"
  value       = module.rds.cluster_endpoint
}

output "aurora_cluster_id" {
  description = "Aurora Serverless cluster identifier"
  value       = module.rds.cluster_id
}

# EFS Outputs
output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = module.efs.file_system_id
}

# Redis Outputs (temporarily disabled)
# output "redis_primary_endpoint" {
#   description = "Primary endpoint for Redis cluster"
#   value       = module.elasticache.redis_primary_endpoint
# }

# output "redis_port" {
#   description = "Port of the Redis cluster"
#   value       = module.elasticache.redis_port
# }

# output "redis_replication_group_id" {
#   description = "ID of the Redis replication group"
#   value       = module.elasticache.redis_replication_group_id
# }

# Route53 Outputs
output "hosted_zone_name_servers" {
  description = "Name servers for the hosted zone"
  value       = module.route53.hosted_zone_name_servers
}

output "ssl_certificate_arn" {
  description = "ARN of the SSL certificate for the domain"
  value       = module.acm.certificate_arn
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = module.route53.hosted_zone_id
}