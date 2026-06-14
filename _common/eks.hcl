# Common EKS defaults – override in each env's terragrunt.hcl as needed.
locals {
  cluster_version = "1.31"

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  # IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Default node group settings shared across envs; instance_types overridden per env.
  eks_managed_node_group_defaults = {
    ami_type                              = "AL2023_x86_64_STANDARD"
    attach_cluster_primary_security_group = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
}
