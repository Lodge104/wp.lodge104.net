variable "source_bucket_name" {
  description = "Name of the existing source S3 bucket that objects are replicated from."
  type        = string
}

variable "source_bucket_arn" {
  description = "ARN of the existing source S3 bucket that objects are replicated from."
  type        = string
}

variable "destination_bucket_name" {
  description = "Name of the destination (archive) S3 bucket to create in destination_region."
  type        = string
}

variable "destination_region" {
  description = "AWS Region the archive bucket is created in."
  type        = string
  default     = "us-west-2"
}

variable "replication_role_name" {
  description = "Name of the IAM role S3 assumes to replicate objects."
  type        = string
}

variable "replication_rule_id" {
  description = "Unique identifier for the replication rule."
  type        = string
  default     = "archive-to-destination-region"
}

variable "tags" {
  description = "Tags applied to the archive bucket and replication IAM role."
  type        = map(string)
  default     = {}
}
