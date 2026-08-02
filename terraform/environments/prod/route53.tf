module "route53_records" {
  source = "../../modules/route53_environment_records"

  zone_name                 = var.zone_name
  site_domain               = var.site_domain
  cloudfront_domain_name    = var.cloudfront_domain_name
  cloudfront_hosted_zone_id = var.cloudfront_hosted_zone_id
  db_endpoint               = var.db_endpoint
  db_reader_endpoint        = var.db_reader_endpoint
  cache_endpoint            = var.cache_endpoint
}
