# -----------------------------------------------------------------------------
# Route53 defaults shared by several stacks (route53-private, global/route53-*).
#
# Lives outside _common/route53.hcl because that file is a full Terragrunt
# fragment with dependency blocks, which read_terragrunt_config() cannot
# evaluate from another stack. Read with:
#   read_terragrunt_config("${get_repo_root()}/_common/shared/route53.hcl").locals
# -----------------------------------------------------------------------------
locals {
  # Records only, in an existing hosted zone – don't let the module
  # create/manage the zone itself (stacks that own a zone override this).
  create_zone = false

  # AWS-published Route53 hosted zone ID for Application Load Balancers in
  # us-east-1 (constant per region, not a Terraform resource attribute).
  # https://docs.aws.amazon.com/general/latest/gr/elb.html
  # Not a route53 module variable; passed through for render parity. Records
  # use region.hcl's alb_hosted_zone_id. Remove in the #45 cleanup phase.
  alb_hosted_zone_id = "Z35SXDOTRQ7X7K"
}
