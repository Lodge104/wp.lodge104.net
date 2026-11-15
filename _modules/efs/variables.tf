variable "name" {
  description = "Name prefix used for the EFS file system, security group, and StorageClass."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EFS mount targets will be created."
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs in which to create EFS mount targets (one per AZ)."
  type        = list(string)
}

variable "eks_cluster_name" {
  description = "EKS cluster name. Used for aws eks get-token and Pod Identity association."
  type        = string
}

variable "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint for the Kubernetes provider."
  type        = string
}

variable "eks_cluster_certificate_authority_data" {
  description = "Base64-encoded EKS cluster CA certificate for the Kubernetes provider."
  type        = string
}

variable "region" {
  description = "AWS region where the EKS cluster is deployed. Passed as --region to aws eks get-token."
  type        = string
}

variable "eks_node_security_group_id" {
  description = "Security group ID attached to EKS managed node groups. Granted NFS ingress to EFS."
  type        = string
}

variable "throughput_mode" {
  description = "EFS throughput mode. Allowed values: bursting, provisioned, elastic."
  type        = string
  default     = "elastic"
}

variable "performance_mode" {
  description = "EFS performance mode. Allowed values: generalPurpose, maxIO."
  type        = string
  default     = "generalPurpose"
}
