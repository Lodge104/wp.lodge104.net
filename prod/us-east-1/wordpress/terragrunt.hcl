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
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    cluster_endpoint = "lodge104-prod.cluster-xxxxxxxxxxxx.us-east-1.rds.amazonaws.com"
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
  timeout       = 900

  set_values = [
    { name = "externalDatabase.host",     value = dependency.rds.outputs.cluster_endpoint },
    { name = "externalDatabase.port",     value = "3306" },
    { name = "externalDatabase.user",     value = "lodge104" },
    { name = "externalDatabase.database", value = "lodge104" },
  ]

  values = [
    local.common.locals.base_values,
    <<-YAML
      wordpressBlogName: "Lodge104"
      wordpressHost: lodge104.net

      replicaCount: 3
      resourcesPreset: large

      ingress:
        hostname: lodge104.net
        extraHosts:
          - name: www.lodge104.net
            path: /

      externalDatabase:
        existingSecret: lodge104-prod-rds-credentials

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
