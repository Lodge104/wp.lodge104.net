variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "parent_domain" {
  description = "Existing parent Route 53 zone that delegates wp.lodge104.net."
  type        = string
  default     = "lodge104.net"
}

variable "shared_domain" {
  description = "Shared public Route 53 zone under the parent domain."
  type        = string
  default     = "wp.lodge104.net"
}

variable "environments" {
  description = "Environment subdomains delegated from the shared Route 53 zone."
  type        = list(string)
  default     = ["prod", "dev", "test"]
}
