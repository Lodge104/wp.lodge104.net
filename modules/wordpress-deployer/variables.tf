variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment (dev, prod, staging)"
  type        = string
}

variable "efs_file_system_id" {
  description = "EFS file system ID for WordPress files"
  type        = string
}

variable "efs_access_point_path" {
  description = "Path for EFS access point"
  type        = string
  default     = "/wordpress"
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda VPC configuration"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for Lambda"
  type        = list(string)
}

variable "db_host" {
  description = "Database host endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "primary_domain" {
  description = "Primary domain name for WordPress"
  type        = string
  default     = ""
}
