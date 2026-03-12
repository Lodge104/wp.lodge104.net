output "site_url" {
  description = "Primary WordPress site URL."
  value       = "https://${var.site_domain}"
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name."
  value       = aws_cloudfront_distribution.wordpress.domain_name
}

output "alb_dns_name" {
  description = "ALB DNS name. Access is restricted to CloudFront only — do not use directly."
  value       = aws_lb.wordpress.dns_name
}

output "rds_endpoint" {
  description = "Aurora cluster writer endpoint."
  value       = aws_rds_cluster.wordpress.endpoint
  sensitive   = false
}

output "rds_reader_endpoint" {
  description = "Aurora cluster reader endpoint."
  value       = aws_rds_cluster.wordpress.reader_endpoint
}

output "efs_id" {
  description = "EFS file system ID."
  value       = aws_efs_file_system.wordpress.id
}

output "valkey_endpoint" {
  description = "ElastiCache Valkey primary endpoint address."
  value       = aws_elasticache_replication_group.valkey.primary_endpoint_address
}

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "packer_ami_id" {
  description = "Latest WordPress AMI found for this environment (used by ASG launch template)."
  value       = data.aws_ami.wordpress.id
}
