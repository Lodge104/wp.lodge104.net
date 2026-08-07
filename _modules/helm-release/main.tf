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
# reference, instead of requiring it to be created manually.
data "aws_secretsmanager_secret_version" "rds_master_user" {
  count = var.rds_master_user_secret_arn != null ? 1 : 0

  secret_id = var.rds_master_user_secret_arn
}

resource "kubernetes_secret_v1" "rds_credentials" {
  count = var.rds_master_user_secret_arn != null ? 1 : 0

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

# Generate the initial WordPress admin user (username and password) with
# random values, store them in AWS Secrets Manager, and sync the password
# into a Kubernetes Secret the chart's top-level `existingSecret` value can
# reference (must contain key "wordpress-password"). This removes the need
# to set/know an admin password up front -- retrieve the generated
# credentials from Secrets Manager after apply.
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

resource "kubernetes_secret_v1" "wordpress_admin" {
  count = var.create_wordpress_admin_credentials ? 1 : 0

  metadata {
    name      = var.wordpress_admin_secret_name
    namespace = var.namespace
  }

  data = {
    "wordpress-password" = random_password.wordpress_admin[0].result
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
        wordpressUsername = jsondecode(aws_secretsmanager_secret_version.wordpress_admin[0].secret_string)["username"]
        existingSecret    = kubernetes_secret_v1.wordpress_admin[0].metadata[0].name
      })
    ] : []
  )

  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.rds_credentials,
    kubernetes_secret_v1.wordpress_admin,
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
