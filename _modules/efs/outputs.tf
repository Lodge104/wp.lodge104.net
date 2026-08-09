output "file_system_id" {
  description = "EFS file system ID."
  value       = aws_efs_file_system.this.id
}

output "file_system_arn" {
  description = "EFS file system ARN."
  value       = aws_efs_file_system.this.arn
}

output "storage_class_name" {
  description = "Kubernetes StorageClass name created for EFS (efs-sc)."
  value       = kubernetes_storage_class_v1.efs_sc.metadata[0].name
}
