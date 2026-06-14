output "release_name" {
  description = "Helm release name."
  value       = helm_release.this.name
}

output "release_namespace" {
  description = "Kubernetes namespace of the Helm release."
  value       = helm_release.this.namespace
}

output "release_status" {
  description = "Current status of the Helm release."
  value       = helm_release.this.status
}
