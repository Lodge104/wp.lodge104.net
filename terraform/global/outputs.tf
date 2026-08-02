output "shared_zone_name_servers" {
  description = "Name servers for the wp.lodge104.net hosted zone."
  value       = aws_route53_zone.shared.name_servers
}

output "environment_zone_name_servers" {
  description = "Name servers for each delegated environment hosted zone."
  value       = { for environment, zone in aws_route53_zone.environment : environment => zone.name_servers }
}
