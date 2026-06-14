locals {
  common      = read_terragrunt_config("${get_repo_root()}/_common/wordpress.hcl")
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
    cluster_name = "lodge104-dev"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    cluster_endpoint = "lodge104-dev.cluster-xxxxxxxxxxxx.us-east-1.rds.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "efs" {
  config_path = "../efs"

  mock_outputs = {
    storage_class_name = "efs-sc"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "${get_repo_root()}//_modules/helm-release"
}

# Generate the Helm provider configuration as a root-module file.
# Providers must not be declared inside reusable child modules.
generate "helm_provider" {
  path      = "helm_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    data "aws_eks_cluster" "wordpress" {
      name = "lodge104-${local.env}"
    }

    provider "helm" {
      kubernetes {
        host                   = data.aws_eks_cluster.wordpress.endpoint
        cluster_ca_certificate = base64decode(data.aws_eks_cluster.wordpress.certificate_authority[0].data)

        exec {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "lodge104-${local.env}", "--region", "${local.region}"]
        }
      }
    }
  EOF
}

inputs = {
  release_name  = local.common.locals.release_name
  repository    = local.common.locals.repository
  chart         = local.common.locals.chart
  chart_version = local.common.locals.chart_version
  namespace     = local.common.locals.namespace
  atomic        = true

  values = [
    local.common.locals.base_values,
    <<-YAML
      wordpressBlogName: "Lodge104 (Dev)"
      wordpressHost: dev.lodge104.net

      replicaCount: 1
      resourcesPreset: small

      externalDatabase:
        host: "${dependency.rds.outputs.cluster_endpoint}"
        port: 3306
        user: lodge104
        database: lodge104
        # Kubernetes Secret with key "mariadb-password".
        # Create via: kubectl create secret generic lodge104-dev-rds-credentials \
        #   --namespace wordpress \
        #   --from-literal=mariadb-password=<aurora-db-password>
        existingSecret: lodge104-dev-rds-credentials

      ingress:
        hostname: dev.lodge104.net

      persistence:
        size: 5Gi

      # Cost savings: disable PDB in dev.
      pdb:
        create: false
    YAML
  ]
}
