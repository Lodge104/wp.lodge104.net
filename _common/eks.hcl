# Common EKS defaults – override in each env's terragrunt.hcl as needed.
# Module: terraform-aws-modules/eks/aws ~> 21.x (requires AWS provider >= 6.0).
locals {
  kubernetes_version = "1.34"

  endpoint_public_access  = true
  endpoint_private_access = true

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
    aws-efs-csi-driver = {
      most_recent = true
    }
  }
}
