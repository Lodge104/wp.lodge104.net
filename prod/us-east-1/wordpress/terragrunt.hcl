locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/wordpress.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env       = local.env_vars.locals.env
  region    = local.region_vars.locals.aws_region
  project   = local.project_vars.locals.project_name
  domain    = local.project_vars.locals.domain
  wp_config = local.env_vars.locals.wordpress
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name = "${local.project}-${local.env}"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    cluster_endpoint = "${local.project}-${local.env}.cluster-xxxxxxxxxxxx.${local.region}.rds.amazonaws.com"
    cluster_master_user_secret = [
      { secret_arn = "arn:aws:secretsmanager:${local.region}:000000000000:secret:mock-xxxxxx" }
    ]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "efs" {
  config_path = "../efs"

  mock_outputs = {
    storage_class_name = "efs-sc"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "elasticache" {
  config_path = "../elasticache"

  mock_outputs = {
    cluster_address = "${local.project}-${local.env}.xxxxxx.cfg.use1.cache.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "acm" {
  config_path = "../acm"

  mock_outputs = {
    acm_certificate_arn = "arn:aws:acm:${local.region}:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "alb_security_group" {
  config_path = "../alb-security-group"

  mock_outputs = {
    id = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

# No outputs needed from eks-addons; this dependency only enforces apply
# ordering so the AWS Load Balancer Controller exists before the WordPress
# Ingress (which relies on it) is created.
dependency "eks_addons" {
  config_path = "../eks-addons"

  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "ses" {
  config_path = "../ses"

  mock_outputs = {
    smtp_username = "mock-smtp-username"
    smtp_password = "mock-smtp-password"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
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
      name = "${dependency.eks.outputs.cluster_name}"
    }

    provider "helm" {
      kubernetes {
        host                   = data.aws_eks_cluster.wordpress.endpoint
        cluster_ca_certificate = base64decode(data.aws_eks_cluster.wordpress.certificate_authority[0].data)

        exec {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.region}"]
        }
      }
    }

    provider "kubernetes" {
      host                   = data.aws_eks_cluster.wordpress.endpoint
      cluster_ca_certificate = base64decode(data.aws_eks_cluster.wordpress.certificate_authority[0].data)

      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.region}"]
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
  rds_secret_name            = "${local.project}-${local.env}-rds-credentials"

  ses_smtp_password = dependency.ses.outputs.smtp_password
  ses_secret_name   = "${local.project}-${local.env}-ses-credentials"

  expose_ingress_hostname = true
  ingress_name            = local.common.locals.release_name

  values = [
    local.common.locals.base_values,
    <<-YAML
      wordpressBlogName: "${local.wp_config.blog_name}"
      wordpressHost: ${local.env}.wp.${local.domain}

      # Multisite (subdomain install): the network's primary domain stays
      # ${local.env}.wp.${local.domain}. Additional network sites (e.g. the
      # store.* site) are added afterwards from wp-admin and can use any
      # domain the proxy/ingress routes to this release -- they don't need
      # to be literal subdomains of DOMAIN_CURRENT_SITE. In production the
      # store site uses store.${local.domain} directly (its DNS is managed
      # outside this repository).
      wordpressExtraConfigContent: |
        define('WP_ALLOW_MULTISITE', true);
        define('MULTISITE', true);
        define('SUBDOMAIN_INSTALL', true);
        define('DOMAIN_CURRENT_SITE', '${local.env}.wp.${local.domain}');
        define('PATH_CURRENT_SITE', '/');
        define('SITE_ID_CURRENT_SITE', 1);
        define('BLOG_ID_CURRENT_SITE', 1);

      replicaCount: ${local.wp_config.replica_count}
      resourcesPreset: ${local.wp_config.resources_preset}

      externalDatabase:
        host: "${dependency.rds.outputs.cluster_endpoint}"
        port: 3306
        user: ${local.project}admin
        database: ${local.project}
        existingSecret: ${local.project}-${local.env}-rds-credentials

      externalCache:
        host: "${dependency.elasticache.outputs.cluster_address}"
        port: 11211

      wordpressConfigureCache: true

      # SES SMTP credentials, generated with terraform (see ../ses). The
      # domain identity and its DKIM/SPF/DMARC DNS records are assumed to
      # already be verified in this account.
      smtpHost: "email-smtp.${local.region}.amazonaws.com"
      smtpPort: "587"
      smtpUser: "${dependency.ses.outputs.smtp_username}"
      smtpProtocol: "tls"
      smtpFromEmail: "wordpress@${local.domain}"
      smtpExistingSecret: "${local.project}-${local.env}-ses-credentials"

      ingress:
        hostname: ${local.env}.wp.${local.domain}

      persistence:
        size: ${local.wp_config.persistence_size}

      podAntiAffinityPreset: ${local.wp_config.pod_anti_affinity_preset}

      autoscaling:
        enabled: true
        minReplicas: 3
        maxReplicas: 10
        targetCPU: 60
        targetMemory: 75

      pdb:
        create: ${local.wp_config.pdb_create}
        minAvailable: ${local.wp_config.pdb_min_available}

      resources:
        requests:
          cpu: 250m
          memory: 512Mi
        limits:
          cpu: 1000m
          memory: 1Gi
    YAML
    ,
    <<-YAML
      ingress:
        annotations:
          alb.ingress.kubernetes.io/certificate-arn: "${dependency.acm.outputs.acm_certificate_arn}"
          alb.ingress.kubernetes.io/security-groups: "${dependency.alb_security_group.outputs.id}"
          alb.ingress.kubernetes.io/manage-backend-security-group-rules: "true"
        # CloudFront forwards the viewer Host header for dynamic Multisite
        # behaviors, but some cache behaviors (for example static assets)
        # still use the origin domain as Host, so the ALB needs a matching
        # rule for origin.${local.env}.wp.${local.domain}.
        extraHosts:
          - name: origin.${local.env}.wp.${local.domain}
            path: /
          # Multisite "store" site. Uses the bare store.${local.domain}
          # (not store.${local.env}.wp.${local.domain}) -- its DNS is
          # managed outside this repository, but the proxy still needs to
          # route it to this release.
          - name: store.${local.domain}
            path: /
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
            secretName: ${local.project}-${local.env}-rds-credentials

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
                if grep -qF -- "$CURRENT_PW" "$WP_CONFIG"; then
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
