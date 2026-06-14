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
    cidr = "10.20.0.0/16"

    azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
    private_subnets = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
    public_subnets  = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]
    intra_subnets   = ["10.20.201.0/24", "10.20.202.0/24", "10.20.203.0/24"]

    # One NAT per AZ for HA testing parity with prod
    single_nat_gateway = false
  }
)
