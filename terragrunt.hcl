# -----------------------------------------------------------------------------
# Root Terragrunt configuration
# Defines remote state backend and shared provider/inputs for all modules.
# -----------------------------------------------------------------------------

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  env    = local.env_vars.locals.env
  region = local.region_vars.locals.aws_region
}

# ---------------------------------------------------------------------------
# Remote state – all envs share one S3 bucket, keys are scoped by path.
# ---------------------------------------------------------------------------
remote_state {
  backend = "s3"
  config = {
    bucket         = "lodge104-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "lodge104-terraform-locks"
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
      required_version = ">= 1.5.0"
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
      }
    }

    provider "aws" {
      region = "${local.region}"

      default_tags {
        tags = {
          Environment = "${local.env}"
          ManagedBy   = "Terragrunt"
          Project     = "lodge104"
        }
      }
    }
  EOF
}

# ---------------------------------------------------------------------------
# Common inputs propagated to every module.
# ---------------------------------------------------------------------------
inputs = {
  env    = local.env
  region = local.region
}
