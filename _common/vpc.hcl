# -----------------------------------------------------------------------------
# vpc – env VPC (public / private / intra subnets across 3 AZs, flow logs).
#
# Env-level knob: `vpc_cidr` in <env>/env.hcl. All subnets are carved out of it
# with cidrsubnet(), so tuning the network = edit that env's env.hcl.
#
# Full Terragrunt fragment included by <env>/<region>/vpc/terragrunt.hcl. Env
# shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx  = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  cidr = local.ctx.env_vars.vpc_cidr

  # Tag required by the AWS Load Balancer Controller to auto-discover subnets
  # for this env's EKS cluster.
  cluster_tag = { "kubernetes.io/cluster/${local.ctx.name}" = "shared" }
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.13.0"
}

inputs = {
  name = local.ctx.name
  cidr = local.cidr

  azs             = ["${local.ctx.region}a", "${local.ctx.region}b", "${local.ctx.region}c"]
  private_subnets = [for n in [1, 2, 3] : cidrsubnet(local.cidr, 8, n)]
  public_subnets  = [for n in [101, 102, 103] : cidrsubnet(local.cidr, 8, n)]
  intra_subnets   = [for n in [201, 202, 203] : cidrsubnet(local.cidr, 8, n)]

  # NAT Gateway removed entirely -- cost optimization decision, see issue #32.
  # EKS worker nodes now run in the public subnets with SG-scoped inbound
  # access instead of routing outbound traffic through a NAT Gateway/instance.
  # RDS/EFS remain on private subnets, which have no default route to the
  # internet.
  enable_nat_gateway = false
  single_nat_gateway = false

  # Required so instances placed in the public subnets (EKS nodes) get a
  # public IP at launch without a NAT Gateway providing egress.
  map_public_ip_on_launch = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  # Bound the flow log CloudWatch Logs group's storage cost -- default
  # (module) behavior retains logs indefinitely.
  flow_log_cloudwatch_log_group_retention_in_days = 14

  # Subnet tags required for EKS / AWS Load Balancer Controller
  # auto-discovery.
  public_subnet_tags  = merge({ "kubernetes.io/role/elb" = 1 }, local.cluster_tag)
  private_subnet_tags = merge({ "kubernetes.io/role/internal-elb" = 1 }, local.cluster_tag)
}
