variable "region" {
  description = "The AWS region to deploy the infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "wordpress"
}

variable "instance_type" {
  description = "The EC2 instance type for WordPress"
  type        = string
  default     = "t3.micro"
}

variable "desired_capacity" {
  description = "The desired number of EC2 instances in the Auto Scaling group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "The maximum number of EC2 instances in the Auto Scaling group"
  type        = number
  default     = 5
}

variable "min_size" {
  description = "The minimum number of EC2 instances in the Auto Scaling group"
  type        = number
  default     = 1
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "The availability zones for the VPC"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "The CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "The CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "database_subnet_cidrs" {
  description = "The CIDR blocks for the database subnets"
  type        = list(string)
  default     = ["10.0.7.0/24", "10.0.8.0/24", "10.0.9.0/24"]
}

# Database Variables
variable "db_name" {
  description = "The name of the database"
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "The username for the Aurora database"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "The password for the Aurora database"
  type        = string
  sensitive   = true
}

# Aurora Serverless Variables
variable "backup_retention_period" {
  description = "The backup retention period in days"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying the cluster"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "auto_pause" {
  description = "Whether to enable automatic pause"
  type        = bool
  default     = true
}

variable "max_capacity" {
  description = "The maximum capacity for Aurora Serverless"
  type        = number
  default     = 4
}

variable "min_capacity" {
  description = "The minimum capacity for Aurora Serverless"
  type        = number
  default     = 1
}

variable "domain_name" {
  description = "The domain name for the WordPress site"
  type        = string
  default     = "example.com"
}

variable "route53_zone_id" {
  description = "The Route53 hosted zone ID for the domain (leave empty to create new zone)"
  type        = string
  default     = ""
}

variable "ssl_certificate_arn" {
  description = "The ARN of the SSL certificate for the domain (will be created automatically if domain_name is provided)"
  type        = string
  default     = ""
}

# Redis Configuration
variable "redis_node_type" {
  description = "The instance class for Redis nodes"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_clusters" {
  description = "Number of cache clusters for Redis replication group"
  type        = number
  default     = 2
}

variable "redis_auth_token" {
  description = "Redis AUTH token for authentication"
  type        = string
  default     = ""
  sensitive   = true
}

# CloudFront Caching Configuration
variable "cloudfront_price_class" {
  description = "CloudFront distribution price class"
  type        = string
  default     = "PriceClass_100"
}

variable "cloudfront_default_ttl" {
  description = "Default TTL for CloudFront cache behavior (seconds)"
  type        = number
  default     = 86400
}

variable "cloudfront_max_ttl" {
  description = "Maximum TTL for CloudFront cache behavior (seconds)"
  type        = number
  default     = 31536000
}

variable "cloudfront_min_ttl" {
  description = "Minimum TTL for CloudFront cache behavior (seconds)"
  type        = number
  default     = 0
}

variable "cloudfront_admin_ttl" {
  description = "TTL for WordPress admin areas (seconds)"
  type        = number
  default     = 0
}

variable "cloudfront_compress" {
  description = "Whether to enable CloudFront compression"
  type        = bool
  default     = true
}

variable "cloudfront_query_string" {
  description = "Whether to forward query strings to origin"
  type        = bool
  default     = true
}

variable "cloudfront_cookies_forward" {
  description = "Cookie forwarding behavior (none, whitelist, all)"
  type        = string
  default     = "whitelist"
}

# Parameter Store Configuration
variable "use_parameter_store" {
  description = "Use AWS Systems Manager Parameter Store for team-shared configuration"
  type        = bool
  default     = false
}

variable "environment" {
  description = "The environment (dev, prod, staging)"
  type        = string
  default     = "dev"
}

# HTTPS Backend Configuration
variable "enable_https_backend" {
  description = "Enable HTTPS communication between ALB and instances for end-to-end encryption"
  type        = bool
  default     = false
}

# Additional Database Variables
variable "db_instance_class" {
  description = "The instance class for the RDS database"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine" {
  description = "The database engine"
  type        = string
  default     = "mysql"
}

# EFS Configuration
variable "efs_performance_mode" {
  description = "The performance mode for the EFS file system"
  type        = string
  default     = "generalPurpose"
}

# Route53 Configuration (Legacy)
variable "route53_domain_name" {
  description = "The domain name for Route53 (legacy variable, use domain_name instead)"
  type        = string
  default     = ""
}

variable "route53_hosted_zone_id" {
  description = "The hosted zone ID for Route53 (legacy variable, use route53_zone_id instead)"
  type        = string
  default     = ""
}

# Additional Aurora Variables
variable "backup_window" {
  description = "The daily time range for backups"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "The weekly maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "seconds_until_auto_pause" {
  description = "The time in seconds before Aurora Serverless is paused"
  type        = number
  default     = 300
}

# Elastic Beanstalk Configuration
variable "eb_solution_stack_name" {
  description = "Elastic Beanstalk solution stack name for PHP"
  type        = string
  default     = "64bit Amazon Linux 2023 v4.8.0 running PHP 8.3"
}

variable "key_name" {
  description = "Key pair name for SSH access to EC2 instances"
  type        = string
  default     = ""
}
