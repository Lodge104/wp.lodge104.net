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

  validation {
    condition     = var.rds_master_user_secret_arn == null || try(trimspace(var.rds_secret_name) != "", false)
    error_message = "When rds_master_user_secret_arn is set, rds_secret_name must be a non-empty string."
  }
}

variable "rds_secret_key" {
  description = "Key within the created Kubernetes Secret's data map that holds the password."
  type        = string
  default     = "mariadb-password"
}

variable "ses_smtp_password" {
  description = "SES SMTP password (e.g. the ses-smtp-user module's `smtp_password` output) to store in a Kubernetes Secret for the chart's `smtpExistingSecret` to reference. When set, a Kubernetes Secret named `ses_secret_name` is created in `namespace` with the password under key `ses_secret_key`."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.ses_smtp_password == null || coalesce(var.ses_smtp_password, "") != ""
    error_message = "When ses_smtp_password is set, it must be a non-empty string."
  }
}

variable "ses_secret_name" {
  description = "Name of the Kubernetes Secret to create from the SES SMTP password. Required when `ses_smtp_password` is set."
  type        = string
  default     = null

  validation {
    condition     = var.ses_smtp_password == null || coalesce(var.ses_secret_name, "") != ""
    error_message = "When ses_smtp_password is set, ses_secret_name must be a non-empty string."
  }
}

variable "ses_secret_key" {
  # The Bitnami WordPress chart's smtpExistingSecret must contain a key
  # named "smtp-password" -- see
  # https://github.com/bitnami/charts/tree/main/bitnami/wordpress#parameters
  description = "Key within the created Kubernetes Secret's data map that holds the SES SMTP password. Must be \"smtp-password\" for the Bitnami WordPress chart's smtpExistingSecret to find it, unless the chart changes this requirement."
  type        = string
  default     = "smtp-password"
}

variable "create_wordpress_admin_credentials" {
  description = "Generate an initial WordPress admin user (random username and password), store the credentials in an AWS Secrets Manager secret, and sync the password into a Kubernetes Secret referenced via the chart's `existingSecret` value."
  type        = bool
  default     = false
}

variable "wordpress_admin_secret_name" {
  description = "Name for the AWS Secrets Manager secret and matching Kubernetes Secret holding the initial WordPress admin credentials. Must be a valid Kubernetes DNS subdomain because it is used unchanged for both resources. Required when `create_wordpress_admin_credentials` is true."
  type        = string
  default     = null

  validation {
    condition     = !var.create_wordpress_admin_credentials || try(trimspace(var.wordpress_admin_secret_name) != "", false)
    error_message = "When create_wordpress_admin_credentials is true, wordpress_admin_secret_name must be a non-empty string."
  }

  validation {
    condition = !var.create_wordpress_admin_credentials || try(
      length(var.wordpress_admin_secret_name) <= 253 && can(regex("^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$", var.wordpress_admin_secret_name)),
      false
    )
    error_message = "When create_wordpress_admin_credentials is true, wordpress_admin_secret_name must be a valid Kubernetes DNS subdomain (lowercase alphanumeric, '-', or '.', start/end alphanumeric, max 253 chars)."
  }
}

variable "wordpress_admin_username_prefix" {
  description = "Prefix used when generating the random initial WordPress admin username (a random alphanumeric suffix is appended)."
  type        = string
  default     = "admin"
}

variable "wordpress_admin_password_length" {
  description = "Length of the randomly generated initial WordPress admin password."
  type        = number
  default     = 24
}

variable "wordpress_admin_secret_recovery_window_in_days" {
  description = "Number of days AWS Secrets Manager waits before permanently deleting the WordPress admin credentials secret after destruction. Set to 0 to delete immediately (useful for ephemeral/dev environments)."
  type        = number
  default     = 0

  validation {
    condition = var.wordpress_admin_secret_recovery_window_in_days == 0 || (
      var.wordpress_admin_secret_recovery_window_in_days >= 7 &&
      var.wordpress_admin_secret_recovery_window_in_days <= 30
    )
    error_message = "wordpress_admin_secret_recovery_window_in_days must be 0 or an integer from 7 through 30."
  }
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

  validation {
    condition     = !var.expose_ingress_hostname || try(trimspace(var.ingress_name) != "", false)
    error_message = "When expose_ingress_hostname is true, ingress_name must be a non-empty string."
  }
}
