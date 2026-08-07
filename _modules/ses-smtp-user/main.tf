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
    effect    = "Allow"
    actions   = ["ses:SendRawEmail", "ses:SendEmail"]
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
