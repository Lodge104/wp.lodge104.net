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
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    cluster_endpoint = "lodge104-test.cluster-xxxxxxxxxxxx.us-east-1.rds.amazonaws.com"
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

dependency "elasticache" {
  config_path = "../elasticache"

  mock_outputs = {
    cluster_address = "lodge104-test.xxxxxx.cfg.use1.cache.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "acm" {
  config_path = "../acm"

  mock_outputs = {
    acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# No outputs needed from eks-addons; this dependency only enforces apply
# ordering so the AWS Load Balancer Controller exists before the WordPress
# Ingress (which relies on it) is created.
dependency "eks_addons" {
  config_path = "../eks-addons"

  mock_outputs                            = {}
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

  rds_master_user_secret_arn = dependency.rds.outputs.cluster_master_user_secret[0].secret_arn
  rds_secret_name             = "lodge104-${local.env}-rds-credentials"

  expose_ingress_hostname = true
  ingress_name            = local.common.locals.release_name

  values = [
    local.common.locals.base_values,
    <<-YAML
      wordpressBlogName: "Lodge104 (Test)"
      wordpressHost: test.lodge104.net

      replicaCount: 2
      resourcesPreset: medium

      externalDatabase:
        host: "${dependency.rds.outputs.cluster_endpoint}"
        port: 3306
        user: lodge104admin
        database: lodge104
        existingSecret: lodge104-test-rds-credentials

      externalCache:
        host: "${dependency.elasticache.outputs.cluster_address}"
        port: 11211

      wordpressConfigureCache: true

      ingress:
        hostname: test.lodge104.net

      persistence:
        size: 10Gi

      podAntiAffinityPreset: soft

      pdb:
        create: true
        minAvailable: 1
    YAML
    ,
    <<-YAML
      ingress:
        annotations:
          alb.ingress.kubernetes.io/certificate-arn: "${dependency.acm.outputs.acm_certificate_arn}"
    YAML
    ,
    <<-YAML
      # Persisted WordPress data lives on EFS and survives RDS cluster
      # replacements / Secrets Manager password rotations. If the DB
      # password baked into the persisted wp-config.php no longer matches
      # the current RDS secret, the chart's "restore" boot path fails to
      # connect and crash-loops. This init container detects that mismatch
      # and wipes the persisted data so the main container does a clean
      # re-install against the current credentials instead.
      extraVolumes:
        - name: rds-credentials-check
          secret:
            secretName: lodge104-${local.env}-rds-credentials

      initContainers:
        - name: reconcile-db-password
          image: docker.io/busybox:1.36
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sh
            - -ec
            - |
              WP_CONFIG=/bitnami/wordpress/wp-config.php
              CURRENT_PW="$(cat /rds-credentials/mariadb-password)"
              if [ -f "$WP_CONFIG" ]; then
                if grep -qF "$CURRENT_PW" "$WP_CONFIG"; then
                  echo "Persisted WordPress DB password matches the current RDS secret; leaving install intact."
                else
                  echo "Persisted WordPress DB password is stale (RDS secret has rotated/changed) -- wiping persisted data for a clean re-install."
                  find /bitnami/wordpress -mindepth 1 -exec rm -rf {} + 2>/dev/null || true
                fi
              else
                echo "No persisted wp-config.php found; nothing to reconcile."
              fi
          volumeMounts:
            - name: wordpress-data
              mountPath: /bitnami/wordpress
              subPath: wordpress
            - name: rds-credentials-check
              mountPath: /rds-credentials
              readOnly: true
    YAML
  ]
}
