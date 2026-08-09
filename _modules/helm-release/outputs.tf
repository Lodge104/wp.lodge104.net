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

output "wordpress_admin_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret holding the initial WordPress admin credentials (username and password), when `create_wordpress_admin_credentials` is true. Null otherwise."
  value       = try(aws_secretsmanager_secret.wordpress_admin[0].arn, null)
}

output "ingress_hostname" {
  description = "Hostname of the load balancer backing the release's Ingress (e.g. an ALB DNS name), when `expose_ingress_hostname` is true. Null otherwise, or if the load balancer isn't provisioned yet."
  value       = try(data.kubernetes_ingress_v1.this[0].status[0].load_balancer[0].ingress[0].hostname, null)
}
