# Common Route53 defaults – override in each env's terragrunt.hcl as needed.
locals {
  # Records only, in the existing public hosted zone for lodge104.net (same
  # zone ACM validates against) – don't let the module create/manage the
  # zone itself.
  create_zone = false
  name        = "lodge104.net"
}
