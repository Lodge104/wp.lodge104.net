resource "random_password" "cf_secret" {
  length  = 48
  special = false # alphanumeric — safe for HTTP header values
}

# ── EFS ──────────────────────────────────────────────────────────────────────────

resource "aws_ssm_parameter" "efs_id" {
  name        = "/lodge104/efs/id"
  type        = "String"
  value       = aws_efs_file_system.wordpress.id
  description = "EFS file system ID for the WordPress shared volume"
}

# ── Database ──────────────────────────────────────────────────────────────────────

resource "aws_ssm_parameter" "db_host" {
  name        = "/lodge104/db/host"
  type        = "String"
  value       = aws_rds_cluster.wordpress.endpoint
  description = "Aurora cluster writer endpoint"
}

resource "aws_ssm_parameter" "db_name" {
  name        = "/lodge104/db/name"
  type        = "String"
  value       = var.db_name
  description = "WordPress database name"
}

resource "aws_ssm_parameter" "db_username" {
  name        = "/lodge104/db/username"
  type        = "String"
  value       = var.db_username
  description = "WordPress database username"
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/lodge104/db/password"
  type        = "SecureString"
  value       = random_password.db.result
  description = "WordPress database password (SecureString)"
}

# ── Cache ─────────────────────────────────────────────────────────────────────────

resource "aws_ssm_parameter" "cache_host" {
  name        = "/lodge104/cache/host"
  type        = "String"
  value       = aws_elasticache_replication_group.valkey.primary_endpoint_address
  description = "ElastiCache Valkey primary endpoint"
}

# ── Application ───────────────────────────────────────────────────────────────────

resource "aws_ssm_parameter" "domain" {
  name        = "/lodge104/app/domain"
  type        = "String"
  value       = var.site_domain
  description = "WordPress site domain"
}

# ── CloudFront origin verification ────────────────────────────────────────────────
# ALB listener rules check for this header to reject traffic not originating from CF.

resource "aws_ssm_parameter" "cf_secret" {
  name        = "/lodge104/cloudfront/secret"
  type        = "SecureString"
  value       = random_password.cf_secret.result
  description = "Secret header value injected by CloudFront; ALB rejects requests without it"
}
