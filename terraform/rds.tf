resource "random_password" "db" {
  length  = 32
  special = false # alphanumeric only — avoids shell-quoting issues in user-data
}

resource "aws_db_subnet_group" "wordpress" {
  name       = "${var.environment}-wordpress-db"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${var.environment}-wordpress-db-subnet-group" }
}

resource "aws_rds_cluster_parameter_group" "wordpress" {
  name   = "${var.environment}-aurora-mysql8"
  family = "aurora-mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = { Name = "${var.environment}-aurora-mysql8-params" }
}

resource "aws_rds_cluster" "wordpress" {
  cluster_identifier     = "${var.environment}-wordpress"
  engine                 = "aurora-mysql"
  engine_version         = "8.0.mysql_aurora.3.12.0"
  database_name          = var.db_name
  master_username        = var.db_username
  master_password        = random_password.db.result

  db_subnet_group_name            = aws_db_subnet_group.wordpress.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.wordpress.name

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  storage_encrypted   = true
  deletion_protection = true

  backup_retention_period      = 7
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  enabled_cloudwatch_logs_exports = ["audit", "error", "slowquery"]

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.environment}-wordpress-final"

  tags = { Name = "${var.environment}-wordpress-aurora" }
}

resource "aws_rds_cluster_instance" "writer" {
  identifier           = "${var.environment}-wordpress-writer"
  cluster_identifier   = aws_rds_cluster.wordpress.id
  instance_class       = "db.serverless"
  engine         = aws_rds_cluster.wordpress.engine
  engine_version = aws_rds_cluster.wordpress.engine_version
  db_subnet_group_name = aws_db_subnet_group.wordpress.name

  auto_minor_version_upgrade   = true
  performance_insights_enabled = true

  tags = { Name = "${var.environment}-wordpress-aurora-writer" }
}
