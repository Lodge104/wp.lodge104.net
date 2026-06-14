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

terraform {
  source = "${get_repo_root()}//_modules/helm-release"
}

inputs = {
  cluster_name  = dependency.eks.outputs.cluster_name
  region        = local.region
  release_name  = local.common.locals.release_name
  repository    = local.common.locals.repository
  chart         = local.common.locals.chart
  chart_version = local.common.locals.chart_version
  namespace     = local.common.locals.namespace
  atomic        = true

  # Dynamic values sourced from dependency outputs – passed via --set.
  set_values = [
    { name = "externalDatabase.host",     value = dependency.rds.outputs.cluster_endpoint },
    { name = "externalDatabase.port",     value = "3306" },
    { name = "externalDatabase.user",     value = "lodge104" },
    { name = "externalDatabase.database", value = "lodge104" },
  ]

  values = [
    local.common.locals.base_values,
    # Environment-specific overrides.
    <<-YAML
      wordpressBlogName: "Lodge104 (Dev)"
      wordpressHost: dev.lodge104.net

      replicaCount: 1
      resourcesPreset: small

      ingress:
        hostname: dev.lodge104.net

      externalDatabase:
        # Kubernetes Secret with key "mariadb-password".
        # Create via: kubectl create secret generic lodge104-dev-rds-credentials \
        #   --namespace wordpress \
        #   --from-literal=mariadb-password=<aurora-db-password>
        existingSecret: lodge104-dev-rds-credentials

      persistence:
        size: 5Gi

      # Cost savings: disable PDB in dev.
      pdb:
        create: false
    YAML
  ]
}
