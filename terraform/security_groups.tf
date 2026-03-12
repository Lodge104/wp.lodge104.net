# CloudFront managed prefix list — used to restrict ALB access to CloudFront only.
# Not referenced while cloudfront.tf is disabled, but the data source is harmless.
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# ── ALB Security Group ────────────────────────────────────────────────────────────
# While CloudFront is disabled, allow HTTP from anywhere so the site is reachable.
# When cloudfront.tf is re-enabled, swap cidr_blocks for prefix_list_ids.

resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-cf-sg"
  description = "Allow inbound HTTP/HTTPS from CloudFront edge nodes only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet (redirected to HTTPS by ALB)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet (403 without CloudFront secret header)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-alb-cf-sg" }
}

# ── EC2 Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "ec2" {
  name        = "${var.environment}-ec2-sg"
  description = "Allow HTTP from ALB; all outbound for package installs and SSM"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound via NAT for package installs and SSM"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-ec2-sg" }
}

# ── RDS Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"
  description = "Allow MySQL from EC2 WordPress instances only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = { Name = "${var.environment}-rds-sg" }
}

# ── ElastiCache Security Group ────────────────────────────────────────────────────

resource "aws_security_group" "elasticache" {
  name        = "${var.environment}-elasticache-sg"
  description = "Allow Valkey/Redis from EC2 WordPress instances only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Valkey from EC2"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = { Name = "${var.environment}-elasticache-sg" }
}

# ── EFS Security Group ─────────────────────────────────────────────────────────────

resource "aws_security_group" "efs" {
  name        = "${var.environment}-efs-sg"
  description = "Allow NFS from EC2 WordPress instances only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from EC2"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = { Name = "${var.environment}-efs-sg" }
}
