terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# The SES domain identity (and its DKIM/DMARC/SPF DNS records) for the
# domain is assumed to already exist in this account -- this module only
# provisions an IAM user scoped to send mail through it, plus the SMTP
# credentials WordPress uses to authenticate.
data "aws_caller_identity" "current" {}

locals {
  identity_arn = "arn:aws:ses:${var.region}:${data.aws_caller_identity.current.account_id}:identity/${var.domain}"
}

resource "aws_iam_user" "smtp" {
  name = var.name
  path = "/ses-smtp/"
}

data "aws_iam_policy_document" "send_email" {
  statement {
    effect = "Allow"
    # SMTP authentication only ever exercises ses:SendRawEmail; SendEmail is
    # intentionally omitted to keep this IAM user scoped to what WordPress's
    # SMTP integration actually needs.
    actions   = ["ses:SendRawEmail"]
    resources = [local.identity_arn]
  }
}

resource "aws_iam_user_policy" "send_email" {
  name   = "${var.name}-send-email"
  user   = aws_iam_user.smtp.name
  policy = data.aws_iam_policy_document.send_email.json
}

resource "aws_iam_access_key" "smtp" {
  user = aws_iam_user.smtp.name
}

# Persisted the same way RDS's master user password and the WordPress admin
# password are -- an IAM access key's secret is only ever shown once, so
# without this it only exists in Terraform state and the WordPress k8s Secret.
resource "aws_secretsmanager_secret" "smtp_credentials" {
  name                    = var.secret_name
  description             = "SES SMTP credentials for the ${var.name} IAM user."
  recovery_window_in_days = var.secret_recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "smtp_credentials" {
  secret_id = aws_secretsmanager_secret.smtp_credentials.id
  secret_string = jsonencode({
    username = aws_iam_access_key.smtp.id
    password = aws_iam_access_key.smtp.ses_smtp_password_v4
  })
}
