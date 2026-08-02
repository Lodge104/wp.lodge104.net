data "aws_route53_zone" "environment" {
  name         = "${var.zone_name}."
  private_zone = false
}

resource "aws_route53_record" "site_a" {
  zone_id = data.aws_route53_zone.environment.zone_id
  name    = var.site_domain
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "site_aaaa" {
  zone_id = data.aws_route53_zone.environment.zone_id
  name    = var.site_domain
  type    = "AAAA"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "db" {
  zone_id = data.aws_route53_zone.environment.zone_id
  name    = "db.${var.zone_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.db_endpoint]
}

resource "aws_route53_record" "db_reader" {
  zone_id = data.aws_route53_zone.environment.zone_id
  name    = "db-reader.${var.zone_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.db_reader_endpoint]
}

resource "aws_route53_record" "cache" {
  zone_id = data.aws_route53_zone.environment.zone_id
  name    = "cache.${var.zone_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.cache_endpoint]
}
