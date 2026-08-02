# Common Route53 defaults – override in each env's terragrunt.hcl as needed.
locals {
  # Records only, in the existing public hosted zone for lodge104.net (same
  # zone ACM validates against) – don't let the module create/manage the
  # zone itself.
  create_zone = false

  # AWS-published Route53 hosted zone ID for Application Load Balancers in
  # us-east-1 (constant per region, not a Terraform resource attribute).
  # https://docs.aws.amazon.com/general/latest/gr/elb.html
  # Overridden by the region.hcl value in each environment.
  alb_hosted_zone_id = "Z35SXDOTRQ7X7K"
}
