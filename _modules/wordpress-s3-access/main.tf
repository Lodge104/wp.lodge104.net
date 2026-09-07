terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "ObjectLevel"
    effect = "Allow"

    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = ["${var.bucket_arn}/*"]
  }

  statement {
    sid    = "BucketLevel"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPublicAccessBlock",
      "s3:ListBucket",
    ]

    resources = [var.bucket_arn]
  }
}

resource "aws_iam_policy" "this" {
  name        = var.policy_name
  description = "WP Offload Media access to ${var.bucket_name}"
  policy      = data.aws_iam_policy_document.this.json
}