resource "aws_elasticache_subnet_group" "valkey" {
  name        = "${var.environment}-valkey-subnet"
  subnet_ids  = aws_subnet.private[*].id
  description = "Subnet group for ElastiCache Valkey"
}

resource "aws_elasticache_parameter_group" "valkey" {
  family      = "valkey7"
  name        = "${var.environment}-valkey7"
  description = "Valkey 7 parameters for WordPress object caching"
}

resource "aws_elasticache_replication_group" "valkey" {
  replication_group_id = "${var.environment}-valkey"
  description          = "Valkey object cache for WordPress (${var.environment})"

  engine         = "valkey"
  engine_version = "7.2"
  node_type      = var.valkey_node_type

  # num_cache_clusters: 1 = primary only; 2 = primary + 1 replica for HA.
  num_cache_clusters = var.valkey_num_nodes

  parameter_group_name = aws_elasticache_parameter_group.valkey.name
  subnet_group_name    = aws_elasticache_subnet_group.valkey.name
  security_group_ids   = [aws_security_group.elasticache.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  transit_encryption_mode    = "preferred" # TLS supported; allows non-TLS for legacy clients

  auto_minor_version_upgrade = true
  maintenance_window         = "sun:05:00-sun:06:00"
  snapshot_retention_limit   = 1
  snapshot_window            = "04:00-05:00"

  tags = { Name = "${var.environment}-valkey" }
}
