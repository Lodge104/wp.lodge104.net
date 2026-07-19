# Common defaults for the ALB-facing security group – restricts the
# WordPress ALB listener to CloudFront's origin-facing IP ranges so the
# origin can't be reached directly, bypassing CloudFront/any WAF in front
# of it. Only the listener port differs nothing per env, so this is fully
# shared.
locals {
  ingress_rules = {
    https_from_cloudfront = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS from CloudFront origin-facing IP ranges"
    }
  }

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all outbound"
    }
  }
}
