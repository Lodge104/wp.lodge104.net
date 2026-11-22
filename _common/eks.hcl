# -----------------------------------------------------------------------------
# eks – EKS cluster + managed node groups.
# Module: terraform-aws-modules/eks/aws ~> 21.x (requires AWS provider >= 6.0).
#
# Env-level knobs (<env>/env.hcl):
#   eks_node_groups              map of managed node groups (sizes, instance
#                                types, capacity type)
#   eks_cluster_autoscaler_tags  tag node groups for Cluster Autoscaler ASG
#                                auto-discovery (default: true)
#
# kubernetes_version lives in _common/shared/eks.hcl so other stacks (bastion)
# can read it.
#
# Full Terragrunt fragment included by <env>/<region>/eks/terragrunt.hcl. Env
# shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx    = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  shared = read_terragrunt_config("${get_repo_root()}/_common/shared/eks.hcl").locals

  cluster_autoscaler_tags = try(local.ctx.env_vars.eks_cluster_autoscaler_tags, true)

  # Default node group settings shared across envs; sizes/instance types come
  # from env.hcl.
  eks_managed_node_group_defaults = {
    # Graviton (arm64) -- cheaper per-vCPU/GiB than x86 for the same
    # workload; the WordPress image and EKS add-ons below all publish
    # arm64 variants. See issue #32.
    ami_type                              = "AL2023_ARM_64_STANDARD"
    attach_cluster_primary_security_group = true
    # WP Offload Media uses the worker instance profile via IMDSv2. A hop
    # limit of 2 allows pod network namespaces to reach IMDS while keeping
    # token authentication required and instance metadata tags disabled.
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
      instance_metadata_tags      = "disabled"
    }
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=21.24.0"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id         = "vpc-00000000000000000"
    public_subnets = ["subnet-00000000000000001", "subnet-00000000000000002", "subnet-00000000000000003"]
    intra_subnets  = ["subnet-00000000000000004", "subnet-00000000000000005", "subnet-00000000000000006"]
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "wordpress_s3_access" {
  config_path = "../wordpress-s3-access"

  mock_outputs = {
    policy_arn = "arn:aws:iam::123456789012:policy/${local.ctx.name}-wordpress-s3-access"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  name               = local.ctx.name
  kubernetes_version = local.shared.kubernetes_version

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  # IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Not a v21 module variable (v21 dropped the defaults merge -- see the
  # per-group merge below); still passed so the rendered inputs are unchanged.
  # Remove in the #45 cleanup phase.
  eks_managed_node_group_defaults = local.eks_managed_node_group_defaults

  addons = {
    coredns = {
      most_recent = true
    }
    # vpc-cni and kube-proxy must be installed before the managed node group
    # is created, otherwise nodes join without a CNI plugin and get stuck
    # NotReady ("cni plugin not initialized") while the node group itself
    # waits forever for the node to become Ready (a deadlock).
    kube-proxy = {
      most_recent    = true
      before_compute = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    # Pinned: an addon update restarts the efs-csi-node pods, which kills the
    # efs-proxy behind every live NFS mount and hangs the WordPress pods
    # (503). After bumping this, restart the wordpress deployment/nodes.
    aws-efs-csi-driver = {
      addon_version = "v3.5.4-eksbuild.1"
    }
    # Required for the aws-efs-csi-driver addon's IAM role (granted via EKS
    # Pod Identity association, see _modules/efs) to actually be injected
    # into the CSI controller pods at runtime.
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  vpc_id = dependency.vpc.outputs.vpc_id
  # Worker nodes run in the public subnets -- NAT Gateway removed, see
  # issue #32. Nodes get a public IP (map_public_ip_on_launch = true on
  # the VPC) and rely on security groups for inbound restriction; the
  # control plane ENIs stay on the intra subnets as before.
  subnet_ids               = dependency.vpc.outputs.public_subnets
  control_plane_subnet_ids = dependency.vpc.outputs.intra_subnets

  eks_managed_node_groups = {
    for name, group in local.ctx.env_vars.eks_node_groups : name => merge(
      group,
      {
        # terraform-aws-modules/eks/aws v21 removed the
        # eks_managed_node_group_defaults merge behavior from the root
        # module -- ami_type must be set explicitly per group or it
        # silently falls back to the module's own default
        # (AL2023_x86_64_STANDARD), which breaks Graviton instance types.
        ami_type         = local.eks_managed_node_group_defaults.ami_type
        metadata_options = local.eks_managed_node_group_defaults.metadata_options
        iam_role_additional_policies = merge(
          local.eks_managed_node_group_defaults.iam_role_additional_policies,
          try(group.iam_role_additional_policies, {}),
          { WordPressS3Access = dependency.wordpress_s3_access.outputs.policy_arn }
        )
      },
      # Cluster Autoscaler (enabled via eks-addons' enable_cluster_autoscaler)
      # discovers which ASGs it's allowed to scale by these tags, instead of
      # managing every ASG in the account. Without them, pods stuck
      # FailedScheduling due to pod anti-affinity never trigger a scale-up.
      local.cluster_autoscaler_tags ? {
        tags = merge(try(group.tags, {}), {
          "k8s.io/cluster-autoscaler/enabled"           = "true"
          "k8s.io/cluster-autoscaler/${local.ctx.name}" = "owned"
        })
      } : {}
    )
  }
}
