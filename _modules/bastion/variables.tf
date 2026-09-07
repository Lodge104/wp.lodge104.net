variable "project_name" {
  description = "Project name prefix used by env stacks (for example net-lodge104-wp)."
  type        = string
}

variable "region" {
  description = "AWS region where the bastion and peerings are managed."
  type        = string
}

variable "environment_names" {
  description = "Environments to discover (bastion will safely skip missing resources)."
  type        = list(string)
}

variable "bastion_home_env_preference" {
  description = "Ordered env preference for where to place the bastion VPC."
  type        = list(string)
}

variable "instance_type" {
  description = "Bastion instance type."
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size (GiB)."
  type        = number
}

variable "transfer_bucket_name" {
  description = "S3 bucket name for file transfers."
  type        = string
}

variable "tags" {
  description = "Extra tags to apply to resources."
  type        = map(string)
  default     = {}
}
