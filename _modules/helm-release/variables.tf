variable "cluster_name" {
  description = "EKS cluster name. Used to look up endpoint and CA data via data source."
  type        = string
}

variable "region" {
  description = "AWS region where the EKS cluster resides (passed to aws eks get-token)."
  type        = string
}

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

variable "set_values" {
  description = "List of name/value pairs passed as --set arguments to Helm. Useful for values sourced from Terragrunt dependency outputs."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "values" {
  description = "List of raw YAML values strings (equivalent to -f values.yaml). Rendered in order; later entries override earlier ones."
  type        = list(string)
  default     = []
}
