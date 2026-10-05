variable "project_name" {
  description = "Project name prefix used by env stacks (for example net-lodge104-wp)."
  type        = string
}

variable "region" {
  description = "AWS region where the bastion, RDS clusters, EFS file systems, and S3 buckets live."
  type        = string
}

variable "bastion_instance_id" {
  description = "Instance ID of the SSM-managed bastion host that runs the promotion script. The bastion must already have VPC peering + EFS mounts to every environment (see _modules/bastion) and the IAM permissions granted there for RDS, Secrets Manager, and the per-environment CDN buckets."
  type        = string
}

variable "bastion_role_arn" {
  description = "IAM role ARN assumed by the bastion instance (the bastion module's `role_arn` output). Granted an EKS access entry + AmazonEKSEditPolicy (namespace-scoped) on every promotion target cluster, so the bastion's post-copy wp search-replace step can kubectl exec into a WordPress pod."
  type        = string
}

variable "domain" {
  description = "Project base domain (e.g. lodge104.net). Used to compute each environment's WordPress hostname (prod uses the bare domain; other environments use <env>.wp.<domain>, matching _common/wordpress.hcl) for the post-copy wp search-replace step."
  type        = string
}

variable "release_name" {
  description = "Helm release name used by the WordPress chart (the helm-release module's release_name input, see _common/wordpress.hcl). Used to find the WordPress pod to exec into."
  type        = string
  default     = "wordpress"
}

variable "wordpress_namespace" {
  description = "Kubernetes namespace the WordPress Helm release is installed into (see _common/wordpress.hcl). The bastion's EKS access entry is scoped to this namespace."
  type        = string
  default     = "wordpress"
}

variable "allowed_promotions" {
  description = "Allow-list of {source, target} environment pairs this function may copy between, e.g. [{source = \"prod\", target = \"test\"}, {source = \"test\", target = \"dev\"}]. Requests outside this list are rejected before anything runs."
  type = list(object({
    source = string
    target = string
  }))
}

variable "ssm_command_timeout_seconds" {
  description = "Maximum time the SSM command running on the bastion is allowed to run. Database dump/restore, EFS rsync, and S3 sync can take a while for large environments, so this is intentionally generous."
  type        = number
  default     = 3600
}

variable "log_retention_in_days" {
  description = "CloudWatch Logs retention for both the Lambda function's own logs and the SSM command output log group."
  type        = number
  default     = 30
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout. The function only submits the SSM command and returns immediately -- it does not wait for the (potentially long-running) copy to finish, since that can exceed Lambda's 15-minute hard limit."
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB."
  type        = number
  default     = 128
}

variable "tags" {
  description = "Extra tags to apply to resources."
  type        = map(string)
  default     = {}
}
