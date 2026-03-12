# ── ACM Certificate ───────────────────────────────────────────────────────────────
# A single cert covering the apex domain and www subdomain.
# CloudFront requires the cert to be in us-east-1 — we deploy everything there.

resource "aws_acm_certificate" "wordpress" {
  domain_name       = var.site_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.environment}-wordpress-cert" }
}

# ── Route 53 zone (pre-existing) ──────────────────────────────────────────────────
# This data source is also used by route53.tf for DNS records.

data "aws_route53_zone" "wordpress" {
  name         = "${var.domain_name}."
  private_zone = false
}

# DNS validation records — automatically created in the existing zone.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wordpress.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.wordpress.zone_id
}

resource "aws_acm_certificate_validation" "wordpress" {
  certificate_arn         = aws_acm_certificate.wordpress.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
