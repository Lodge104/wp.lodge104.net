locals {
  common      = read_terragrunt_config("${get_repo_root()}/_common/eks-addons.hcl")
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  env    = local.env_vars.locals.env
  region = local.region_vars.locals.aws_region
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name      = "lodge104-prod"
    cluster_endpoint  = "https://example.eks.amazonaws.com"
    cluster_version   = "1.36"
    oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/00000000000000000000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

terraform {
  source = "tfr:///aws-ia/eks-blueprints-addons/aws?version=1.24.3"
}

# Generate the Helm/Kubernetes provider configuration as a root-module file.
# Providers must not be declared inside reusable child modules.
generate "helm_provider" {
  path      = "helm_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    data "aws_eks_cluster" "eks_addons" {
      name = "lodge104-${local.env}"
    }

    provider "helm" {
      kubernetes {
        host                   = data.aws_eks_cluster.eks_addons.endpoint
        cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_addons.certificate_authority[0].data)

        exec {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "lodge104-${local.env}", "--region", "${local.region}"]
        }
      }
    }

    provider "kubernetes" {
      host                   = data.aws_eks_cluster.eks_addons.endpoint
      cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_addons.certificate_authority[0].data)

      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", "lodge104-${local.env}", "--region", "${local.region}"]
      }
    }
  EOF
}

inputs = merge(
  local.common.locals,
  {
    cluster_name      = dependency.eks.outputs.cluster_name
    cluster_endpoint  = dependency.eks.outputs.cluster_endpoint
    cluster_version   = dependency.eks.outputs.cluster_version
    oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  }
)
