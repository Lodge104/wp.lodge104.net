output "enabled" {
  description = "Whether a bastion instance was created."
  value       = local.create_bastion
}

output "instance_id" {
  description = "Bastion instance ID when enabled."
  value       = local.create_bastion ? aws_instance.bastion[0].id : null
}

output "instance_private_ip" {
  description = "Bastion private IP when enabled."
  value       = local.create_bastion ? aws_instance.bastion[0].private_ip : null
}

output "mounted_efs_creation_tokens" {
  description = "Discovered EFS creation tokens configured for mount."
  value       = [for mount in local.efs_mount_descriptors : mount.token]
}

output "peered_vpc_names" {
  description = "VPC names peered with the bastion VPC."
  value       = sort(keys(local.peer_vpcs))
}
