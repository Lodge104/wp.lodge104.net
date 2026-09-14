terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Namespace is managed here (instead of via helm's create_namespace) so that
# it's guaranteed to exist before the RDS credentials Secret below is created.
resource "kubernetes_namespace_v1" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

# Optionally sync the RDS-managed master user password (AWS Secrets Manager)
# into a Kubernetes Secret the chart's externalDatabase.existingSecret can
# reference, instead of requiring it to be created manually. Skipped when
# use_secrets_store_csi_driver is true, since the SecretProviderClass below
# owns that Secret instead (kept continuously in sync, not a static snapshot).
data "aws_secretsmanager_secret_version" "rds_master_user" {
  count = var.rds_master_user_secret_arn != null && !var.use_secrets_store_csi_driver ? 1 : 0

  secret_id = var.rds_master_user_secret_arn
}

resource "kubernetes_secret_v1" "rds_credentials" {
  count = var.rds_master_user_secret_arn != null && !var.use_secrets_store_csi_driver ? 1 : 0

  metadata {
    name      = var.rds_secret_name
    namespace = var.namespace
  }

  data = {
    (var.rds_secret_key) = jsondecode(data.aws_secretsmanager_secret_version.rds_master_user[0].secret_string)["password"]
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace_v1.this]
}

# When use_secrets_store_csi_driver is true, grant the release's Kubernetes
# service account read access to the RDS secret via EKS Pod Identity, and
# create a SecretProviderClass that mounts it and keeps rds_secret_name
# synced to the live Secrets Manager value (survives password rotation
# without any custom reconciliation logic or stale wp-config.php files).
data "aws_iam_policy_document" "rds_secret_pod_identity_trust" {
  count = var.use_secrets_store_csi_driver ? 1 : 0

  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_secret_reader" {
  count = var.use_secrets_store_csi_driver ? 1 : 0

  name               = "${var.namespace}-${var.release_name}-rds-secret-reader"
  assume_role_policy = data.aws_iam_policy_document.rds_secret_pod_identity_trust[0].json
}

data "aws_iam_policy_document" "rds_secret_read" {
  count = var.use_secrets_store_csi_driver ? 1 : 0

  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [var.rds_master_user_secret_arn]
  }
}

resource "aws_iam_role_policy" "rds_secret_reader" {
  count = var.use_secrets_store_csi_driver ? 1 : 0

  name   = "read-rds-secret"
  role   = aws_iam_role.rds_secret_reader[0].id
  policy = data.aws_iam_policy_document.rds_secret_read[0].json
}

resource "aws_iam_role_policy_attachment" "wordpress_s3_access" {
  count = var.use_secrets_store_csi_driver && var.wordpress_s3_access_policy_arn != null ? 1 : 0

  role       = aws_iam_role.rds_secret_reader[0].name
  policy_arn = var.wordpress_s3_access_policy_arn
}

resource "aws_eks_pod_identity_association" "rds_secret_reader" {
  count = var.use_secrets_store_csi_driver ? 1 : 0

  cluster_name    = var.eks_cluster_name
  namespace       = var.namespace
  service_account = var.pod_identity_service_account
  role_arn        = aws_iam_role.rds_secret_reader[0].arn
}

resource "kubernetes_manifest" "rds_secret_provider_class" {
  count = var.use_secrets_store_csi_driver ? 1 : 0

  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"
    metadata = {
      name      = "${var.release_name}-rds"
      namespace = var.namespace
    }
    spec = {
      provider = "aws"
      parameters = {
        usePodIdentity = "true"
        objects = yamlencode([
          {
            objectName = var.rds_master_user_secret_arn
            objectType = "secretsmanager"
            jmesPath = [
              { path = "password", objectAlias = var.rds_secret_key }
            ]
          }
        ])
      }
      secretObjects = [
        {
          secretName = var.rds_secret_name
          type       = "Opaque"
          data = [
            { objectName = var.rds_secret_key, key = var.rds_secret_key }
          ]
        }
      ]
    }
  }

  depends_on = [aws_eks_pod_identity_association.rds_secret_reader, kubernetes_namespace_v1.this]
}

# Generate the initial WordPress admin user (username and password) with
# random values, store them in AWS Secrets Manager, then read the stored
# credentials back so the chart consumes the persisted values. The password
# is also synced into a Kubernetes Secret the chart's top-level
# `existingSecret` value can reference (must contain key
# "wordpress-password"). This removes the need to set/know an admin
# password up front -- retrieve the generated credentials from Secrets
# Manager after apply.
resource "random_string" "wordpress_admin_username" {
  count = var.create_wordpress_admin_credentials ? 1 : 0

  length  = 8
  special = false
  upper   = false
}

resource "random_password" "wordpress_admin" {
  count = var.create_wordpress_admin_credentials ? 1 : 0

  length           = var.wordpress_admin_password_length
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "aws_secretsmanager_secret" "wordpress_admin" {
  count = var.create_wordpress_admin_credentials ? 1 : 0

  name                    = var.wordpress_admin_secret_name
  description             = "Initial WordPress admin user credentials for the ${var.release_name} release."
  recovery_window_in_days = var.wordpress_admin_secret_recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "wordpress_admin" {
  count = var.create_wordpress_admin_credentials ? 1 : 0

  secret_id = aws_secretsmanager_secret.wordpress_admin[0].id
  secret_string = jsonencode({
    username = "${var.wordpress_admin_username_prefix}-${random_string.wordpress_admin_username[0].result}"
    password = random_password.wordpress_admin[0].result
  })
}

# Secrets Manager is eventually consistent -- reading the version back
# immediately after creation can race and fail with "couldn't find resource",
# so give it a moment to propagate first.
resource "time_sleep" "wait_for_wordpress_admin_secret" {
  count = var.create_wordpress_admin_credentials ? 1 : 0

  depends_on      = [aws_secretsmanager_secret_version.wordpress_admin]
  create_duration = "10s"
}

data "aws_secretsmanager_secret_version" "wordpress_admin" {
  count = var.create_wordpress_admin_credentials ? 1 : 0

  secret_id = aws_secretsmanager_secret.wordpress_admin[0].id

  depends_on = [time_sleep.wait_for_wordpress_admin_secret]
}

resource "kubernetes_secret_v1" "wordpress_admin" {
  count = var.create_wordpress_admin_credentials ? 1 : 0

  metadata {
    name      = var.wordpress_admin_secret_name
    namespace = var.namespace
  }

  data = {
    "wordpress-password" = jsondecode(data.aws_secretsmanager_secret_version.wordpress_admin[0].secret_string)["password"]
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace_v1.this]
}

# Optionally sync the SES SMTP credentials (AWS Secrets Manager secret
# created by the ses-smtp-user module) into a Kubernetes Secret the chart's
# smtpExistingSecret can reference, instead of requiring it to be created
# manually.
data "aws_secretsmanager_secret_version" "ses_smtp_credentials" {
  count = var.ses_smtp_credentials_secret_arn != null ? 1 : 0

  secret_id = var.ses_smtp_credentials_secret_arn
}

resource "kubernetes_secret_v1" "ses_smtp_credentials" {
  count = var.ses_smtp_credentials_secret_arn != null ? 1 : 0

  metadata {
    name      = var.ses_secret_name
    namespace = var.namespace
  }

  data = {
    (var.ses_secret_key) = jsondecode(data.aws_secretsmanager_secret_version.ses_smtp_credentials[0].secret_string)["password"]
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace_v1.this]
}

resource "helm_release" "this" {
  name             = var.release_name
  repository       = var.repository
  chart            = var.chart
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = false
  timeout          = var.timeout
  wait             = var.wait
  atomic           = var.atomic

  values = concat(
    var.values,
    var.create_wordpress_admin_credentials ? [
      yamlencode({
        wordpressUsername = jsondecode(data.aws_secretsmanager_secret_version.wordpress_admin[0].secret_string)["username"]
        existingSecret    = kubernetes_secret_v1.wordpress_admin[0].metadata[0].name
      })
    ] : []
  )

  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.rds_credentials,
    kubernetes_secret_v1.wordpress_admin,
    kubernetes_secret_v1.ses_smtp_credentials,
  ]
}

# The load balancer backing a Kubernetes Ingress (e.g. an ALB provisioned by
# the AWS Load Balancer Controller) isn't necessarily ready the instant helm
# reports the release as installed -- give it time to actually provision
# before reading its hostname back.
resource "time_sleep" "wait_for_ingress" {
  count = var.expose_ingress_hostname ? 1 : 0

  depends_on      = [helm_release.this]
  create_duration = "120s"
}

data "kubernetes_ingress_v1" "this" {
  count = var.expose_ingress_hostname ? 1 : 0

  metadata {
    name      = var.ingress_name
    namespace = var.namespace
  }

  depends_on = [time_sleep.wait_for_ingress]
}
