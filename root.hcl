# -----------------------------------------------------------------------------
# Root Terragrunt configuration (root.hcl)
# Defines remote state backend and shared provider/inputs for all modules.
#
# Named root.hcl (not terragrunt.hcl) per current Terragrunt convention so the
# repo root is never mistaken for a unit. Every stack includes it with
#   include "root" { path = find_in_parent_folders("root.hcl") }
# The state key is still derived from path_relative_to_include(), i.e. the
# stack path relative to this file, so the rename does not move any state.
# -----------------------------------------------------------------------------

# Note: env/region context is resolved by _common/_env.hcl (read from the
# stack or its _common/<stack>.hcl fragment), not here.

locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  project_name = local.project_vars.locals.project_name
}

# ---------------------------------------------------------------------------
# Remote state – all envs share one S3 bucket, keys are scoped by path.
# ---------------------------------------------------------------------------
remote_state {
  backend = "s3"
  config = {
    bucket       = "${local.project_name}-terraform-state"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# ---------------------------------------------------------------------------
# Provider – generated into every module directory at plan/apply time.
# ---------------------------------------------------------------------------
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.9.0"
    }

    # Region and tags are set via the AWS_DEFAULT_REGION env var and the
    # inputs passed by each child module's terragrunt.hcl.
    provider "aws" {}
  EOF
}
