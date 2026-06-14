# Common ElastiCache (Valkey) defaults – override in each env's terragrunt.hcl as needed.
# Valkey is the open-source Redis-compatible engine supported by AWS ElastiCache.
locals {
  engine         = "valkey"
  engine_version = "7.2"

  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_window          = "04:00-05:00"
  snapshot_retention_limit = 5

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"

  apply_immediately  = true
  auto_minor_version_upgrade = true

  # Parameter group family for Valkey 7
  parameter_group_family = "valkey7"
}
