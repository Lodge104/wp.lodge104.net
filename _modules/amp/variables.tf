variable "workspace_alias" {
  description = "Alias for the Amazon Managed Service for Prometheus (AMP) workspace."
  type        = string
}

variable "eks_cluster_arn" {
  description = "ARN of the EKS cluster the scraper collects metrics from."
  type        = string
}

variable "eks_cluster_security_group_id" {
  description = "Security group ID of the EKS cluster (cluster_security_group_id), attached to the scraper's cross-account ENIs."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs that must be associated with the EKS cluster's VPC config (resourcesVpcConfig.subnetIds) -- the scraper's ENIs are created here, and AMP rejects subnets the cluster isn't actually configured with."
  type        = list(string)
}

variable "scrape_interval" {
  description = "How often the managed scraper collects metrics."
  type        = string
  default     = "30s"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the scraper's own collector/service-discovery logs."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags applied to the AMP workspace."
  type        = map(string)
  default     = {}
}
