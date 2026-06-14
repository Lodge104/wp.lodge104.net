# Common RDS defaults – override in each env's terragrunt.hcl as needed.
locals {
  engine               = "mysql"
  engine_version       = "8.0"
  family               = "mysql8.0"
  major_engine_version = "8.0"

  port    = 3306
  db_name = "lodge104"

  # Credentials should be sourced from AWS Secrets Manager or SSM in real deployments.
  manage_master_user_password = true

  backup_retention_period = 7
  backup_window           = "03:00-06:00"
  maintenance_window      = "Mon:00:00-Mon:03:00"

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  create_monitoring_role = true
  monitoring_interval    = 60

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  auto_minor_version_upgrade = true
  apply_immediately          = false
}
