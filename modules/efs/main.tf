resource "aws_efs_file_system" "wordpress_efs" {
  creation_token   = "${var.project_name}-efs-${var.environment}"
  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode

  provisioned_throughput_in_mibps = var.throughput_mode == "provisioned" ? var.provisioned_throughput_in_mibps : null

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name        = "${var.project_name}-efs-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_efs_mount_target" "wordpress_efs_mount" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.wordpress_efs.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [var.security_group_id]
}