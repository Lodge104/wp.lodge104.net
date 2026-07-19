variable "release_name" {
  description = "Helm release name."
  type        = string
}

variable "repository" {
  description = "Helm chart OCI repository URL (e.g. oci://registry-1.docker.io/bitnamicharts)."
  type        = string
}

variable "chart" {
  description = "Helm chart name."
  type        = string
}

variable "chart_version" {
  description = "Helm chart version to pin."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the release."
  type        = string
  default     = "default"
}

variable "create_namespace" {
  description = "Create the Kubernetes namespace if it does not already exist."
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Time in seconds to wait for Helm operations to complete."
  type        = number
  default     = 600
}

variable "wait" {
  description = "Wait until all Kubernetes resources are in a ready state."
  type        = bool
  default     = true
}

variable "atomic" {
  description = "Roll back the release automatically on failure."
  type        = bool
  default     = false
}

variable "values" {
  description = "List of raw YAML values strings (equivalent to -f values.yaml). Rendered in order; later entries override earlier ones."
  type        = list(string)
  default     = []
}

variable "rds_master_user_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret holding the RDS master user credentials (the rds-aurora module's `cluster_master_user_secret[0].secret_arn` output, populated when `manage_master_user_password = true`). When set, a Kubernetes Secret named `rds_secret_name` is created in `namespace` with the password under key `rds_secret_key`, removing the need to create it manually."
  type        = string
  default     = null
}

variable "rds_secret_name" {
  description = "Name of the Kubernetes Secret to create from the RDS master user secret. Required when `rds_master_user_secret_arn` is set."
  type        = string
  default     = null
}

variable "rds_secret_key" {
  description = "Key within the created Kubernetes Secret's data map that holds the password."
  type        = string
  default     = "mariadb-password"
}

variable "expose_ingress_hostname" {
  description = "Read back the hostname of a Kubernetes Ingress created by this release (e.g. an ALB DNS name) once it's provisioned, exposed via the `ingress_hostname` output."
  type        = bool
  default     = false
}

variable "ingress_name" {
  description = "Name of the Kubernetes Ingress resource to read back when `expose_ingress_hostname` is true. Required when `expose_ingress_hostname` is set."
  type        = string
  default     = null
}
