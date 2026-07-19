# Common ElastiCache (Memcached) defaults – override in each env's terragrunt.hcl as needed.
# Memcached (not Valkey/Redis) is used so the Bitnami WordPress chart's native
# externalCache + W3 Total Cache integration can talk to it directly (that
# integration speaks the memcached wire protocol, not Redis).
locals {
  engine         = "memcached"
  engine_version = "1.6.22"

  create_cluster           = true
  create_replication_group = false

  maintenance_window = "sun:05:00-sun:06:00"

  # Memcached doesn't support at-rest encryption or snapshots (Redis-only
  # features); in-transit encryption IS supported from 1.6.12+.
  transit_encryption_enabled = true

  apply_immediately          = true
  auto_minor_version_upgrade = true

  # Parameter group family for Memcached 1.6
  parameter_group_family = "memcached1.6"
}
