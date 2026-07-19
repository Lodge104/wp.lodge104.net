# Common EKS addons (via aws-ia/eks-blueprints-addons) defaults – override in
# each env's terragrunt.hcl as needed.
locals {
  enable_aws_load_balancer_controller = true
}
