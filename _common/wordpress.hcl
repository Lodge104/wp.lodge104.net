# -----------------------------------------------------------------------------
# wordpress – Bitnami WordPress (multisite) Helm release on EKS, behind the
# ALB ingress and CloudFront.
# Chart version and release name/namespace: _common/shared/wordpress.hcl.
#
# Helm values are composed from files in _common/wordpress/ (applied in
# order; later blocks override earlier ones, lists are replaced wholesale):
#   base.yaml               shared chart values (all envs). Bundled MariaDB is
#                           disabled – Aurora MySQL Serverless (RDS) is used
#                           instead; externalDatabase.existingSecret is the
#                           Secrets Store CSI-synced RDS secret.
#   env-values.yaml.tpl     per-env sizing/hosts/DB/HPA/PDB/resources
#   ingress.yaml.tpl        ALB annotations + extra ingress hosts
#   remoteip.yaml.tpl       RDS secrets volume + Apache mod_remoteip config
#   wellknown-hook.yaml     .well-known postStart symlink hook (optional)
#
# Env-level knobs (<env>/env.hcl, `wordpress = { ... }` map unless noted):
#   blog_name, replica_count, resources_preset, persistence_size,
#   pod_anti_affinity_preset, pdb_create, pdb_min_available   (required)
#   hpa_enabled              default true
#   hpa_max_replicas         default 10 in prod, 2 otherwise
#   resource_limits          explicit requests/limits (default true)
#   skip_install             wordpressSkipInstall (default: is_prod; null
#                            omits the key -> chart default)
#   www_redirect             www.<domain> -> <domain> 301 in wp-config
#                            (default true)
#   root_domain_ingress_hosts  route <domain>, www., store. on the ingress
#                            (default true)
#   wellknown_hook           .well-known postStart hook (default true)
#   helm_timeout             helm_release timeout seconds (default 900;
#                            null -> module default)
#   admin_secret_recovery_window_in_days  default 7 (null -> module default)
#   serves_root_domain (top-level) -> canonical wordpressHost = <domain>
#
# Full Terragrunt fragment included by <env>/<region>/wordpress/
# terragrunt.hcl. Env shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  rds = read_terragrunt_config("${get_repo_root()}/_common/shared/rds.hcl").locals
  wp  = local.ctx.env_vars.wordpress

  # Chart / release identifiers (shared with global/env-promotion).
  release       = read_terragrunt_config("${get_repo_root()}/_common/shared/wordpress.hcl").locals
  chart         = local.release.chart
  repository    = local.release.repository
  chart_version = local.release.chart_version
  release_name  = local.release.release_name
  namespace     = local.release.namespace

  # CloudFront's global "origin-facing" managed prefix list -- the same one
  # _common/alb-security-group.hcl restricts ALB ingress to. Resolved here
  # at plan/apply time (not hardcoded) so it can't go stale as AWS updates
  # the list. These CIDRs (plus the env's VPC CIDR) are fed to Apache's
  # mod_remoteip via the mounted config file (_common/wordpress/
  # remoteip.yaml.tpl),
  # so Apache can correctly peel both proxy hops -- the ALB and the
  # CloudFront edge -- off the X-Forwarded-For chain and resolve the real
  # visitor IP instead of REMOTE_ADDR/X-Forwarded-For showing one of
  # CloudFront's/the ALB's own IPs. Without this, WordPress and plugins
  # that key security logic off the client IP (e.g. Defender Security's
  # Session Protection, which locks a session to the client IP and kills
  # it the moment the IP "changes") see a different CloudFront-owned IP on
  # almost every request and misbehave accordingly.
  cloudfront_origin_facing_prefix_list_id = run_cmd(
    "--terragrunt-quiet",
    "aws", "ec2", "describe-managed-prefix-lists",
    "--filters", "Name=prefix-list-name,Values=com.amazonaws.global.cloudfront.origin-facing",
    "--query", "PrefixLists[0].PrefixListId",
    "--output", "text"
  )

  cloudfront_origin_facing_cidrs = jsondecode(run_cmd(
    "--terragrunt-quiet",
    "aws", "ec2", "get-managed-prefix-list-entries",
    "--prefix-list-id", local.cloudfront_origin_facing_prefix_list_id,
    "--query", "Entries[].Cidr",
    "--output", "json"
  ))

  # Hops Apache's mod_remoteip should trust and peel off the
  # X-Forwarded-For chain to resolve the real visitor IP: the VPC CIDR
  # (the ALB's own hop into the pod) and CloudFront's origin-facing
  # ranges (the hop the ALB appends, representing the CloudFront edge).
  apache_remoteip_internal_proxies = concat(
    [local.ctx.env_vars.vpc_cidr],
    local.cloudfront_origin_facing_cidrs
  )

  rds_secret_name = "${local.ctx.name}-rds-credentials"

  # Feature flags (see header). Defaults match test/prod; dev opts out.
  flags = {
    hpa_enabled               = try(local.wp.hpa_enabled, true)
    hpa_max_replicas          = try(local.wp.hpa_max_replicas, local.ctx.is_prod ? 10 : 2)
    resource_limits           = try(local.wp.resource_limits, true)
    skip_install              = try(local.wp.skip_install, local.ctx.is_prod)
    www_redirect              = try(local.wp.www_redirect, true)
    root_domain_ingress_hosts = try(local.wp.root_domain_ingress_hosts, true)
    wellknown_hook            = try(local.wp.wellknown_hook, true)
    helm_timeout              = try(local.wp.helm_timeout, 900)
    admin_recovery_days       = try(local.wp.admin_secret_recovery_window_in_days, 7)
  }

  # Prod's canonical site is the apex domain; other envs use <env>.wp.<domain>.
  wordpress_host = local.ctx.serves_root_domain ? local.ctx.domain : local.ctx.env_domain

  # One "RemoteIPTrustedProxy <cidr>" line per trusted hop, indented to sit
  # inside the deflate.conf block scalar of the ConfigMap (render parity
  # with the pre-#45 values).
  # The trailing 8 spaces reproduce the closing heredoc indentation the
  # pre-#45 inline values ended with.
  remoteip_trusted_proxies = "${join("", [
    for cidr in local.apache_remoteip_internal_proxies : "                      RemoteIPTrustedProxy ${cidr}\n"
  ])}        "
}

terraform {
  source = "${get_repo_root()}//_modules/helm-release"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name                       = local.ctx.name
    cluster_endpoint                   = "https://example.eks.amazonaws.com"
    cluster_certificate_authority_data = base64encode(file("${get_repo_root()}/_common/mock-ca.pem"))
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    cluster_endpoint = "${local.ctx.name}.cluster-xxxxxxxxxxxx.${local.ctx.region}.rds.amazonaws.com"
    cluster_master_user_secret = [
      { secret_arn = "arn:aws:secretsmanager:${local.ctx.region}:000000000000:secret:mock-xxxxxx" }
    ]
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "wordpress_s3_access" {
  config_path = "../wordpress-s3-access"

  mock_outputs = {
    policy_arn = "arn:aws:iam::123456789012:policy/${local.ctx.name}-wordpress-s3-access"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# No outputs needed from efs; this dependency only enforces apply ordering so
# the efs-sc StorageClass exists before the WordPress PVC is created.
dependency "efs" {
  config_path = "../efs"

  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "acm" {
  config_path = "../acm"

  mock_outputs = {
    acm_certificate_arn = "arn:aws:acm:${local.ctx.region}:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "alb_security_group" {
  config_path = "../alb-security-group"

  mock_outputs = {
    id = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# No outputs needed from eks-addons; this dependency only enforces apply
# ordering so the AWS Load Balancer Controller exists before the WordPress
# Ingress (which relies on it) is created.
dependency "eks_addons" {
  config_path = "../eks-addons"

  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "ses" {
  config_path = "../ses"

  mock_outputs = {
    access_key_id     = "AKIAIOSFODNN7EXAMPLE" # cspell:disable-line
    secret_access_key = "mock-secret-access-key"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

generate "helm_provider" {
  path      = "helm_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "helm" {
      kubernetes {
        host                   = "${dependency.eks.outputs.cluster_endpoint}"
        cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

        exec {
          api_version = "client.authentication.k8s.io/v1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.ctx.region}"]
        }
      }
    }

    provider "kubernetes" {
      host                   = "${dependency.eks.outputs.cluster_endpoint}"
      cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

      exec {
        api_version = "client.authentication.k8s.io/v1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.ctx.region}"]
      }
    }
  EOF
}

inputs = merge(
  {
    release_name  = local.release_name
    repository    = local.repository
    chart         = local.chart
    chart_version = local.chart_version
    namespace     = local.namespace
    atomic        = true

    rds_master_user_secret_arn = dependency.rds.outputs.cluster_master_user_secret[0].secret_arn
    rds_secret_name            = local.rds_secret_name

    # The RDS secret is mounted via the AWS Secrets Store CSI Driver (Pod
    # Identity) instead of a static Terraform-managed snapshot, so it stays in
    # sync across password rotations without any custom reconciliation logic.
    use_secrets_store_csi_driver   = true
    eks_cluster_name               = dependency.eks.outputs.cluster_name
    pod_identity_service_account   = local.release_name
    wordpress_s3_access_policy_arn = dependency.wordpress_s3_access.outputs.policy_arn

    create_wordpress_admin_credentials = true
    wordpress_admin_secret_name        = "${local.ctx.name}-wordpress-admin-credentials"

    expose_ingress_hostname = true
    ingress_name            = local.release_name

    values = concat(
      [
        file("${get_repo_root()}/_common/wordpress/base.yaml"),
        templatefile("${get_repo_root()}/_common/wordpress/env-values.yaml.tpl", merge(local.flags, {
          blog_name                = local.wp.blog_name
          wordpress_host           = local.wordpress_host
          env_domain               = local.ctx.env_domain
          domain                   = local.ctx.domain
          replica_count            = local.wp.replica_count
          resources_preset         = local.wp.resources_preset
          persistence_size         = local.wp.persistence_size
          pod_anti_affinity_preset = local.wp.pod_anti_affinity_preset
          pdb_create               = local.wp.pdb_create
          pdb_min_available        = try(local.wp.pdb_min_available, 1)
          db_host                  = dependency.rds.outputs.cluster_endpoint
          db_user                  = local.rds.master_username
          db_name                  = local.rds.database_name
          rds_secret_name          = local.rds_secret_name
          ses_access_key_id        = try(coalesce(dependency.ses.outputs.access_key_id), "")
          ses_secret_access_key    = try(coalesce(dependency.ses.outputs.secret_access_key), "")
        })),
        templatefile("${get_repo_root()}/_common/wordpress/ingress.yaml.tpl", {
          acm_certificate_arn       = dependency.acm.outputs.acm_certificate_arn
          alb_security_group_id     = dependency.alb_security_group.outputs.id
          env_domain                = local.ctx.env_domain
          domain                    = local.ctx.domain
          root_domain_ingress_hosts = local.flags.root_domain_ingress_hosts
        }),
        templatefile("${get_repo_root()}/_common/wordpress/remoteip.yaml.tpl", {
          rds_secret_name          = local.rds_secret_name
          release_name             = local.release_name
          namespace                = local.namespace
          remoteip_trusted_proxies = local.remoteip_trusted_proxies
        }),
      ],
      local.flags.wellknown_hook ? [file("${get_repo_root()}/_common/wordpress/wellknown-hook.yaml")] : [],
    )
  },
  local.flags.helm_timeout != null ? { timeout = local.flags.helm_timeout } : {},
  local.flags.admin_recovery_days != null ? { wordpress_admin_secret_recovery_window_in_days = local.flags.admin_recovery_days } : {},
)
