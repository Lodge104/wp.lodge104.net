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
    cluster_name = "lodge104-prod"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    cluster_endpoint = "lodge104-prod.cluster-xxxxxxxxxxxx.us-east-1.rds.amazonaws.com"
    cluster_master_user_secret = [
      { secret_arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret:mock-xxxxxx" }
    ]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "efs" {
  config_path = "../efs"

  mock_outputs = {
    storage_class_name = "efs-sc"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
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

    provider "kubernetes" {
      host                   = data.aws_eks_cluster.wordpress.endpoint
      cluster_ca_certificate = base64decode(data.aws_eks_cluster.wordpress.certificate_authority[0].data)

      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", "lodge104-${local.env}", "--region", "${local.region}"]
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
  timeout       = 900

  rds_master_user_secret_arn = dependency.rds.outputs.cluster_master_user_secret[0].secret_arn
  rds_secret_name             = "lodge104-${local.env}-rds-credentials"

  values = [
    local.common.locals.base_values,
    <<-YAML
      wordpressBlogName: "Lodge104"
      wordpressHost: lodge104.net

      replicaCount: 3
      resourcesPreset: large

      externalDatabase:
        host: "${dependency.rds.outputs.cluster_endpoint}"
        port: 3306
        user: lodge104admin
        database: lodge104
        existingSecret: lodge104-prod-rds-credentials

      ingress:
        hostname: lodge104.net
        extraHosts:
          - name: www.lodge104.net
            path: /

      persistence:
        size: 20Gi

      podAntiAffinityPreset: hard

      autoscaling:
        enabled: true
        minReplicas: 3
        maxReplicas: 10
        targetCPU: 60
        targetMemory: 75

      pdb:
        create: true
        minAvailable: 2

      resources:
        requests:
          cpu: 250m
          memory: 512Mi
        limits:
          cpu: 1000m
          memory: 1Gi
    YAML
  ]
}
