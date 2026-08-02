data "aws_route53_zone" "parent" {
  name         = "${var.parent_domain}."
  private_zone = false
}

resource "aws_route53_zone" "shared" {
  name = var.shared_domain
}

resource "aws_route53_record" "shared_ns" {
  allow_overwrite = true
  zone_id         = data.aws_route53_zone.parent.zone_id
  name            = var.shared_domain
  type            = "NS"
  ttl             = 300
  records         = aws_route53_zone.shared.name_servers
}

resource "aws_route53_zone" "environment" {
  for_each = toset(var.environments)

  name = "${each.value}.${var.shared_domain}"
}

resource "aws_route53_record" "environment_ns" {
  for_each = aws_route53_zone.environment

  allow_overwrite = true
  zone_id         = aws_route53_zone.shared.zone_id
  name            = each.value.name
  type            = "NS"
  ttl             = 300
  records         = each.value.name_servers
}
