# -----------------------------------------------------------------------------
# WordPress Helm release identifiers shared with OTHER stacks (e.g.
# global/env-promotion, which runs wp-cli against every env's release).
#
# Lives outside _common/wordpress.hcl because that file is a full Terragrunt
# fragment (env-dependent locals + dependency blocks), which
# read_terragrunt_config() cannot evaluate from another stack. Read with:
#   read_terragrunt_config("${get_repo_root()}/_common/shared/wordpress.hcl").locals
# -----------------------------------------------------------------------------
locals {
  # Source: https://artifacthub.io/packages/helm/bitnami/wordpress
  chart         = "wordpress"
  repository    = "oci://registry-1.docker.io/bitnamicharts"
  chart_version = "32.1.1"
  release_name  = "wordpress"
  namespace     = "wordpress"
}
