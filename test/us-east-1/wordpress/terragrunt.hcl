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
    cluster_name = "lodge104-test"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    cluster_endpoint = "lodge104-test.cluster-xxxxxxxxxxxx.us-east-1.rds.amazonaws.com"
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

  set_values = [
    { name = "externalDatabase.host",     value = dependency.rds.outputs.cluster_endpoint },
    { name = "externalDatabase.port",     value = "3306" },
    { name = "externalDatabase.user",     value = "lodge104" },
    { name = "externalDatabase.database", value = "lodge104" },
  ]

  values = [
    local.common.locals.base_values,
    <<-YAML
      wordpressBlogName: "Lodge104 (Test)"
      wordpressHost: test.lodge104.net

      replicaCount: 2
      resourcesPreset: medium

      ingress:
        hostname: test.lodge104.net

      externalDatabase:
        existingSecret: lodge104-test-rds-credentials

      persistence:
        size: 10Gi

      podAntiAffinityPreset: soft

      pdb:
        create: true
        minAvailable: 1
    YAML
  ]
}
