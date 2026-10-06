output "workspace_id" {
  description = "ID of the AMP workspace."
  value       = aws_prometheus_workspace.this.id
}

output "workspace_arn" {
  description = "ARN of the AMP workspace."
  value       = aws_prometheus_workspace.this.arn
}

output "workspace_endpoint" {
  description = "Prometheus-compatible query endpoint for the AMP workspace."
  value       = aws_prometheus_workspace.this.prometheus_endpoint
}

output "scraper_id" {
  description = "ID of the AMP managed scraper."
  value       = aws_prometheus_scraper.this.id
}

output "scraper_role_arn" {
  description = "ARN of the IAM role the managed scraper uses to discover/collect/produce metrics."
  value       = aws_prometheus_scraper.this.role_arn
}
