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
}
