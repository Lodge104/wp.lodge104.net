locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/eks.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  region  = local.region_vars.locals.aws_region
  project = local.project_vars.locals.project_name
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id         = "vpc-00000000000000000"
    public_subnets = ["subnet-00000000000000001", "subnet-00000000000000002", "subnet-00000000000000003"]
    intra_subnets  = ["subnet-00000000000000004", "subnet-00000000000000005", "subnet-00000000000000006"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "wordpress_s3_access" {
  config_path = "../wordpress-s3-access"

  mock_outputs = {
    policy_arn = "arn:aws:iam::123456789012:policy/${local.project}-${local.env}-wordpress-s3-access"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=21.24.0"
}

inputs = merge(
  local.common.locals,
  {
    name = "${local.project}-${local.env}"

    vpc_id = dependency.vpc.outputs.vpc_id
    # Worker nodes run in the public subnets -- NAT Gateway removed, see
    # issue #32. Nodes get a public IP (map_public_ip_on_launch = true on
    # the VPC) and rely on security groups for inbound restriction; the
    # control plane ENIs stay on the intra subnets as before.
    subnet_ids               = dependency.vpc.outputs.public_subnets
    control_plane_subnet_ids = dependency.vpc.outputs.intra_subnets

    eks_managed_node_groups = {
      for name, group in local.env_vars.locals.eks_node_groups : name => merge(group, {
        # terraform-aws-modules/eks/aws v21 removed the
        # eks_managed_node_group_defaults merge behavior from the root
        # module -- ami_type must be set explicitly per group or it
        # silently falls back to the module's own default
        # (AL2023_x86_64_STANDARD), which breaks Graviton instance types.
        ami_type          = local.common.locals.eks_managed_node_group_defaults.ami_type
        metadata_options = local.common.locals.eks_managed_node_group_defaults.metadata_options
        iam_role_additional_policies = merge(
          local.common.locals.eks_managed_node_group_defaults.iam_role_additional_policies,
          try(group.iam_role_additional_policies, {}),
          { WordPressS3Access = dependency.wordpress_s3_access.outputs.policy_arn }
        )
      })
    }
  }
)
