locals {
  common      = read_terragrunt_config("${get_repo_root()}/_common/vpc.hcl")
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  env    = local.env_vars.locals.env
  region = local.region_vars.locals.aws_region
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.13.0"
}

inputs = merge(
  local.common.locals,
  {
    name = "lodge104-${local.env}"
    cidr = "10.10.0.0/16"

    azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
    private_subnets = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
    public_subnets  = ["10.10.101.0/24", "10.10.102.0/24", "10.10.103.0/24"]
    intra_subnets   = ["10.10.201.0/24", "10.10.202.0/24", "10.10.203.0/24"]

    # Cost optimisation: single NAT in dev
    single_nat_gateway = true
  }
)
