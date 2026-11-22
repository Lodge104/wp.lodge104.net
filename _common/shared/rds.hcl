# -----------------------------------------------------------------------------
# Aurora values shared with OTHER stacks (e.g. wordpress' external DB config,
# _modules/env-promotion/files/ssm-promote.sh).
#
# Lives outside _common/rds.hcl because that file is a full Terragrunt fragment
# with dependency blocks, which read_terragrunt_config() cannot evaluate from
# another stack. Read with:
#   read_terragrunt_config("${get_repo_root()}/_common/shared/rds.hcl").locals
# -----------------------------------------------------------------------------
locals {
  database_name   = "lodge104"
  master_username = "lodge104admin"
}
