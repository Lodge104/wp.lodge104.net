# Look up the newest lodge104 WordPress AMI built by Packer.
data "aws_ami" "wordpress" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["lodge104-wordpress-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ── Launch Template ───────────────────────────────────────────────────────────────

resource "aws_launch_template" "wordpress" {
  name_prefix   = "${var.environment}-wordpress-"
  image_id      = data.aws_ami.wordpress.id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2.arn
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  # Enforce IMDSv2 to prevent SSRF credential theft.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(file("${path.module}/templates/user_data.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-wordpress"
      Environment = var.environment
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.environment}-wordpress-vol"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Auto Scaling Group ────────────────────────────────────────────────────────────

resource "aws_autoscaling_group" "wordpress" {
  name_prefix         = "${var.environment}-wordpress-"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = aws_subnet.private[*].id

  launch_template {
    id      = aws_launch_template.wordpress.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.wordpress.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Warm pool — pre-initialized instances shorten scale-out latency.
  # pool_state = "Stopped" saves cost; instances cold-start from stopped state.
  # The systemd mount-efs.service + fstab ensure EFS is remounted on restart.
  warm_pool {
    pool_state                  = "Stopped"
    min_size                    = var.asg_warm_pool_min_size
    max_group_prepared_capacity = var.asg_warm_pool_max_prepared

    instance_reuse_policy {
      reuse_on_scale_in = true
    }
  }

  termination_policies = ["OldestLaunchTemplate", "OldestInstance"]

  # Rolling instance refresh when launch template changes.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-wordpress"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }

  depends_on = [
    aws_efs_mount_target.wordpress,
    aws_rds_cluster_instance.writer,
    aws_elasticache_replication_group.valkey,
    aws_ssm_parameter.efs_id,
    aws_ssm_parameter.db_host,
    aws_ssm_parameter.db_name,
    aws_ssm_parameter.db_username,
    aws_ssm_parameter.db_password,
    aws_ssm_parameter.cache_host,
    aws_ssm_parameter.domain,
  ]
}

# ── Scaling Policies ──────────────────────────────────────────────────────────────

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.environment}-wordpress-cpu"
  autoscaling_group_name = aws_autoscaling_group.wordpress.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}

resource "aws_autoscaling_policy" "alb_requests" {
  name                   = "${var.environment}-wordpress-alb-requests"
  autoscaling_group_name = aws_autoscaling_group.wordpress.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.wordpress.arn_suffix}/${aws_lb_target_group.wordpress.arn_suffix}"
    }
    target_value = 1000.0
  }
}
