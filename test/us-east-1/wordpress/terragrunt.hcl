locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/wordpress.hcl")
  rds_common   = read_terragrunt_config("${get_repo_root()}/_common/rds.hcl")
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

dependency "wordpress_s3_access" {
  config_path = "../wordpress-s3-access"

  mock_outputs = {
    policy_arn = "arn:aws:iam::123456789012:policy/${local.project}-${local.env}-wordpress-s3-access"
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
    smtp_username               = "mock-smtp-username"
    smtp_credentials_secret_arn = "arn:aws:secretsmanager:${local.region}:000000000000:secret:mock-ses-xxxxxx"
    access_key_id               = "AKIAIOSFODNN7EXAMPLE"
    secret_access_key           = "mock-secret-access-key"
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
          api_version = "client.authentication.k8s.io/v1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.region}"]
        }
      }
    }

    provider "kubernetes" {
      host                   = data.aws_eks_cluster.wordpress.endpoint
      cluster_ca_certificate = base64decode(data.aws_eks_cluster.wordpress.certificate_authority[0].data)

      exec {
        api_version = "client.authentication.k8s.io/v1"
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

  rds_master_user_secret_arn = dependency.rds.outputs.cluster_master_user_secret[0].secret_arn
  rds_secret_name            = "${local.project}-${local.env}-rds-credentials"

  # The RDS secret is mounted via the AWS Secrets Store CSI Driver (Pod
  # Identity) instead of a static Terraform-managed snapshot, so it stays in
  # sync across password rotations without any custom reconciliation logic.
  use_secrets_store_csi_driver = true
  eks_cluster_name             = dependency.eks.outputs.cluster_name
  pod_identity_service_account = local.common.locals.release_name
  wordpress_s3_access_policy_arn = dependency.wordpress_s3_access.outputs.policy_arn

  create_wordpress_admin_credentials = true
  wordpress_admin_secret_name        = "${local.project}-${local.env}-wordpress-admin-credentials"

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
      # to be literal subdomains of DOMAIN_CURRENT_SITE.
      multisite:
        host: ${local.env}.wp.${local.domain}

      replicaCount: ${local.wp_config.replica_count}
      resourcesPreset: ${local.wp_config.resources_preset}

      externalDatabase:
        host: "${dependency.rds.outputs.cluster_endpoint}"
        port: 3306
        user: ${local.rds_common.locals.master_username}
        database: ${local.rds_common.locals.database_name}
        existingSecret: ${local.project}-${local.env}-rds-credentials

      externalCache:
        host: "${dependency.elasticache.outputs.cluster_address}"
        port: 11211

      wordpressConfigureCache: true

      wordpressExtraConfigContent: |
        define( 'WP_CACHE', true );
        define( 'AS3CF_SETTINGS', serialize( array(
            'provider' => 'aws',
            'use-server-roles' => true,
        ) ) );
        define( 'FLUENTMAIL_AWS_ACCESS_KEY_ID', '${dependency.ses.outputs.access_key_id}' );
        define( 'FLUENTMAIL_AWS_SECRET_ACCESS_KEY', '${dependency.ses.outputs.secret_access_key}' );

      ingress:
        hostname: ${local.env}.wp.${local.domain}

      persistence:
        size: ${local.wp_config.persistence_size}

      podAntiAffinityPreset: ${local.wp_config.pod_anti_affinity_preset}

      autoscaling:
        enabled: false

      pdb:
        create: ${local.wp_config.pdb_create}
        minAvailable: ${local.wp_config.pdb_min_available}
    YAML
    ,
    <<-YAML
      ingress:
        annotations:
          alb.ingress.kubernetes.io/certificate-arn: "${dependency.acm.outputs.acm_certificate_arn}"
          alb.ingress.kubernetes.io/security-groups: "${dependency.alb_security_group.outputs.id}"
          alb.ingress.kubernetes.io/manage-backend-security-group-rules: "true"
          alb.ingress.kubernetes.io/load-balancer-attributes: "idle_timeout.timeout_seconds=120,routing.http2.enabled=true"
          alb.ingress.kubernetes.io/target-group-attributes: "stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=86400,load_balancing.algorithm.type=least_outstanding_requests"
        # CloudFront forwards the viewer Host header for dynamic Multisite
        # behaviors, but some cache behaviors (for example static assets)
        # still use the origin domain as Host, so the ALB needs a matching
        # rule for origin.${local.env}.wp.${local.domain}.
        extraHosts:
          - name: origin.${local.env}.wp.${local.domain}
            path: /
          # Multisite "store" site, routed to this same release/ingress.
          # pathType must be explicit: extraHosts defaults to ImplementationSpecific,
          # which ALB treats as an exact "/" match instead of a prefix, so only the
          # homepage would route and every asset path would fail.
          - name: store.${local.env}.wp.${local.domain}
            path: /
            pathType: Prefix
    YAML
    ,
    <<-YAML
      # The RDS password is mounted via the AWS Secrets Store CSI Driver
      # (SecretProviderClass created by the helm-release module), which keeps
      # ${local.project}-${local.env}-rds-credentials in sync with Secrets
      # Manager on rotation. Mounting the volume is what triggers the sync.
      extraVolumes:
        - name: rds-secrets-store
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: ${local.common.locals.release_name}-rds

      extraVolumeMounts:
        - name: rds-secrets-store
          mountPath: /mnt/secrets-store/rds
          readOnly: true
    YAML
  ]
}
