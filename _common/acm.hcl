# Common ACM defaults – override in each env's terragrunt.hcl as needed.
locals {
  domain_name = "lodge104.net"

  subject_alternative_names = [
    "*.lodge104.net",
  ]

  validation_method   = "DNS"
  wait_for_validation = true
}
