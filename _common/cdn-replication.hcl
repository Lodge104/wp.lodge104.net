# -----------------------------------------------------------------------------
# cdn-replication – S3 replication of the env's uploads (CDN) bucket to an
# archive bucket in another Region (Glacier Deep Archive).
#
# Prod-only by decision (#45): only prod/us-east-1/cdn-replication includes
# this fragment; there is no dev/test copy and no env.hcl toggle.
#
# Full Terragrunt fragment included by prod/us-east-1/cdn-replication/
# terragrunt.hcl.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
}

terraform {
  source = "${get_repo_root()}/_modules/s3-replication"
}

dependency "cdn" {
  config_path = "../cdn"

  mock_outputs = {
    cdn_bucket_name = "${local.ctx.name}-cdn"
    cdn_bucket_arn  = "arn:aws:s3:::${local.ctx.name}-cdn"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  source_bucket_name = dependency.cdn.outputs.cdn_bucket_name
  source_bucket_arn  = dependency.cdn.outputs.cdn_bucket_arn

  # Archive copy lives in a separate Region from every other resource in
  # this project (us-east-1) -- a deliberate blast-radius/DR choice, not a
  # mistake, so it's hardcoded here rather than read from region.hcl.
  destination_bucket_name = "${local.ctx.name}-cdn-archive"
  destination_region      = "us-west-2"

  replication_role_name = "${local.ctx.name}-cdn-replication"
  replication_rule_id   = "${local.ctx.env}-cdn-archive-deep-archive"
}
