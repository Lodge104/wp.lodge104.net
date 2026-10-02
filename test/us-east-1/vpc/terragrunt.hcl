locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/vpc.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env         = local.env_vars.locals.env
  region      = local.region_vars.locals.aws_region
  project     = local.project_vars.locals.project_name
  cidr_prefix = local.env_vars.locals.vpc_cidr
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
    name = "${local.project}-${local.env}"
    cidr = local.cidr_prefix

    azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
    private_subnets = [cidrsubnet(local.cidr_prefix, 8, 1), cidrsubnet(local.cidr_prefix, 8, 2), cidrsubnet(local.cidr_prefix, 8, 3)]
    public_subnets  = [cidrsubnet(local.cidr_prefix, 8, 101), cidrsubnet(local.cidr_prefix, 8, 102), cidrsubnet(local.cidr_prefix, 8, 103)]
    intra_subnets   = [cidrsubnet(local.cidr_prefix, 8, 201), cidrsubnet(local.cidr_prefix, 8, 202), cidrsubnet(local.cidr_prefix, 8, 203)]

    # NAT Gateway removed entirely -- cost optimization decision, see issue
    # #32. EKS worker nodes now run in the public subnets with SG-scoped
    # inbound access instead of routing outbound traffic through a NAT
    # Gateway/instance. RDS/EFS remain on private subnets, which have no
    # default route to the internet.
    enable_nat_gateway = false

    # Required so instances placed in the public subnets (EKS nodes) get a
    # public IP at launch without a NAT Gateway providing egress.
    map_public_ip_on_launch = true

    # Additional tag (on top of the common role tags) required by the AWS
    # Load Balancer Controller to auto-discover subnets for this cluster.
    public_subnet_tags = merge(
      local.common.locals.public_subnet_tags,
      { "kubernetes.io/cluster/${local.project}-${local.env}" = "shared" }
    )
    private_subnet_tags = merge(
      local.common.locals.private_subnet_tags,
      { "kubernetes.io/cluster/${local.project}-${local.env}" = "shared" }
    )
  }
)
