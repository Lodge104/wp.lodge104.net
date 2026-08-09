# Common Aurora MySQL Serverless v2 defaults – override in each env's terragrunt.hcl as needed.
locals {
  engine                = "aurora-mysql"
  engine_version        = "8.0.mysql_aurora.3.08.0"
  engine_mode           = "provisioned" # Serverless v2 uses provisioned mode with db.serverless instances
  family                = "aurora-mysql8.0"
  major_engine_version  = "8.0"

  port          = 3306
  database_name = "lodge104"

  # Credentials managed via AWS Secrets Manager (rotate automatically).
  master_username              = "lodge104admin"
  manage_master_user_password = true

  backup_retention_period = 7
  preferred_backup_window           = "03:00-06:00"
  preferred_maintenance_window      = "mon:00:00-mon:03:00"

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  create_monitoring_role = true
  monitoring_interval    = 60

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  auto_minor_version_upgrade = true
  apply_immediately          = false

  # Serverless v2 requires at least one instance of class db.serverless.
  instance_class = "db.serverless"

  # Module defaults create_db_subnet_group to false (expects an existing
  # group); we want it created from the subnets/vpc_id we pass in.
  create_db_subnet_group = true
}
