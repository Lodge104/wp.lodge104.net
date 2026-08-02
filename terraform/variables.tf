variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g. prod, staging). Used as a prefix/tag for all resources."
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Public Route 53 zone name for this environment. The shared DNS config should delegate this zone from wp.lodge104.net."
  type        = string
  default     = "prod.wp.lodge104.net"
}

variable "site_domain" {
  description = "FQDN of the WordPress site (ACM cert and CloudFront alias). This should normally match the delegated environment zone apex."
  type        = string
  default     = "prod.wp.lodge104.net"
}

# ── Networking ──────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the new VPC."
  type        = string
  default     = "10.0.0.0/16"
}

# ── Compute ─────────────────────────────────────────────────────────────────────

variable "instance_type" {
  description = "EC2 instance type for WordPress web servers."
  type        = string
  default     = "t3.small"
}

variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group."
  type        = number
  default     = 10
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group."
  type        = number
  default     = 1
}

variable "asg_warm_pool_min_size" {
  description = "Minimum number of pre-initialized instances held in the warm pool."
  type        = number
  default     = 1
}

variable "asg_warm_pool_max_prepared" {
  description = "Maximum total prepared capacity across warm pool + active ASG."
  type        = number
  default     = 3
}

# ── Database ─────────────────────────────────────────────────────────────────────

variable "db_name" {
  description = "WordPress database name."
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "WordPress database master username."
  type        = string
  default     = "wpuser"
}

variable "aurora_min_capacity" {
  description = "Aurora Serverless v2 minimum capacity units (ACUs). 0.5 = ~1 GB RAM."
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Aurora Serverless v2 maximum capacity units (ACUs)."
  type        = number
  default     = 16
}

# ── Cache ────────────────────────────────────────────────────────────────────────

variable "valkey_node_type" {
  description = "ElastiCache node type for Valkey."
  type        = string
  default     = "cache.t4g.small"
}

variable "valkey_num_nodes" {
  description = "Number of ElastiCache nodes (1 = primary only; 2 = primary + replica)."
  type        = number
  default     = 2
}
