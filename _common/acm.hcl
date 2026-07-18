# Common ACM defaults – override in each env's terragrunt.hcl as needed.
locals {
  domain_name = "lodge104.net"

  subject_alternative_names = [
    "*.lodge104.net",
  ]

  validation_method   = "DNS"
  wait_for_validation = true

  # Public hosted zone for lodge104.net – all envs validate their
  # subdomain/wildcard certs against this same Route53 zone.
  zone_id = "Z02518842QX1X2K88785A"
}
