# -----------------------------------------------------------------------------
# EKS values shared with OTHER stacks (e.g. global/bastion's kubectl version).
#
# Lives outside _common/eks.hcl because that file is a full Terragrunt fragment
# with dependency blocks, which read_terragrunt_config() cannot evaluate from
# another stack. Read with:
#   read_terragrunt_config("${get_repo_root()}/_common/shared/eks.hcl").locals
# -----------------------------------------------------------------------------
locals {
  kubernetes_version = "1.37"
}
