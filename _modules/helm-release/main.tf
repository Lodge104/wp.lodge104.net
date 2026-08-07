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

# Optionally sync SES SMTP credentials (generated with terraform, e.g. by
# the ses-smtp-user module) into a Kubernetes Secret the chart's
# smtpExistingSecret can reference, instead of requiring it to be created
# manually.
resource "kubernetes_secret_v1" "ses_smtp_credentials" {
  count = var.ses_smtp_password != null ? 1 : 0

  metadata {
    name      = var.ses_secret_name
    namespace = var.namespace
  }

  data = {
    (var.ses_secret_key) = var.ses_smtp_password
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

  values = var.values

  depends_on = [kubernetes_namespace_v1.this, kubernetes_secret_v1.rds_credentials, kubernetes_secret_v1.ses_smtp_credentials]
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
