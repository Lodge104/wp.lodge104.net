terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

locals {
  # Clusters that could ever be a promotion *target* -- the ones the bastion
  # needs post-copy kubectl access to in order to run wp search-replace.
  target_envs = distinct([for p in var.allowed_promotions : p.target])

  # Only grant access entries for clusters that actually exist yet, so this
  # module can be applied before every environment is bootstrapped (mirrors
  # the existence-checking pattern in _modules/bastion).
  existing_target_envs = toset([
    for env in local.target_envs : env
    if contains(data.aws_eks_clusters.all.names, "${var.project_name}-${env}")
  ])
}

data "aws_eks_clusters" "all" {}

# ---------------------------------------------------------------------------
# SSM Command document that performs the actual copy on the bastion host.
# The bastion already has VPC peering + EFS mounts to every environment and
# the mariadb client / rsync / AWS CLI installed (see _modules/bastion), so
# this document just runs a shell script there with the source/target
# environment names substituted in as SSM document parameters.
# ---------------------------------------------------------------------------
resource "aws_ssm_document" "promote" {
  name            = "${var.project_name}-env-promotion"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Copies the WordPress Aurora MySQL database, EFS content, and CDN S3 bucket between ${var.project_name} environments, then runs wp search-replace in the target cluster to fix up domains."
    parameters = {
      ProjectName = {
        type        = "String"
        description = "Project name prefix (e.g. net-lodge104-wp)."
        default     = var.project_name
      }
      SourceEnv = {
        type        = "String"
        description = "Environment to copy from, e.g. prod."
      }
      TargetEnv = {
        type        = "String"
        description = "Environment to copy to, e.g. test."
      }
      Region = {
        type        = "String"
        description = "AWS region."
        default     = var.region
      }
      Domain = {
        type        = "String"
        description = "Project base domain (e.g. lodge104.net), used to compute each environment's WordPress hostname."
        default     = var.domain
      }
      ReleaseName = {
        type        = "String"
        description = "Helm release name of the WordPress chart, used to find the pod to exec wp search-replace in."
        default     = var.release_name
      }
      Namespace = {
        type        = "String"
        description = "Kubernetes namespace the WordPress release is installed into."
        default     = var.wordpress_namespace
      }
    }
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "promoteEnvironment"
        inputs = {
          timeoutSeconds = tostring(var.ssm_command_timeout_seconds)
          runCommand     = split("\n", file("${path.module}/files/ssm-promote.sh"))
        }
      }
    ]
  })

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Grants the bastion's IAM role Kubernetes access to every promotion target
# cluster (namespace-scoped to the WordPress release's namespace), so the
# post-copy step in files/ssm-promote.sh can "aws eks update-kubeconfig" and
# kubectl exec into a WordPress pod to run wp search-replace.
# AmazonEKSEditPolicy includes pods/exec -- see
# https://docs.aws.amazon.com/eks/latest/userguide/access-policy-permissions.html
# ---------------------------------------------------------------------------
resource "aws_eks_access_entry" "bastion" {
  for_each = local.existing_target_envs

  cluster_name  = "${var.project_name}-${each.value}"
  principal_arn = var.bastion_role_arn
  type          = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "bastion_edit" {
  for_each = local.existing_target_envs

  cluster_name  = "${var.project_name}-${each.value}"
  principal_arn = var.bastion_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [var.wordpress_namespace]
  }

  depends_on = [aws_eks_access_entry.bastion]
}

# ---------------------------------------------------------------------------
# CloudWatch Logs group that SSM streams the command's stdout/stderr into,
# so Lambda doesn't have to wait around for a potentially hour-long copy to
# finish just to surface the output.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ssm_command" {
  name              = "/${var.project_name}/env-promotion/ssm-command"
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-env-promotion"
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

# ---------------------------------------------------------------------------
# Lambda function -- validates the requested source/target pair against the
# allow-list, then submits (but does not wait on) the SSM command.
# ---------------------------------------------------------------------------
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/files/lambda"
  output_path = "${path.module}/files/lambda.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project_name}-env-promotion"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid    = "AllowLambdaLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }

  statement {
    sid    = "AllowSendCommand"
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
    ]
    resources = [
      aws_ssm_document.promote.arn,
      "arn:aws:ec2:${var.region}:*:instance/${var.bastion_instance_id}",
    ]
  }

  statement {
    sid    = "AllowCommandStatusLookup"
    effect = "Allow"
    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
      "ssm:ListCommands",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${var.project_name}-env-promotion"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_lambda_function" "promote" {
  function_name = "${var.project_name}-env-promotion"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.13"
  timeout       = var.lambda_timeout_seconds
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      BASTION_INSTANCE_ID         = var.bastion_instance_id
      SSM_DOCUMENT_NAME           = aws_ssm_document.promote.name
      PROJECT_NAME                = var.project_name
      REGION                      = var.region
      DOMAIN                      = var.domain
      RELEASE_NAME                = var.release_name
      WORDPRESS_NAMESPACE         = var.wordpress_namespace
      ALLOWED_PROMOTIONS          = jsonencode(var.allowed_promotions)
      SSM_COMMAND_TIMEOUT_SECONDS = tostring(var.ssm_command_timeout_seconds)
      CLOUDWATCH_LOG_GROUP_NAME   = aws_cloudwatch_log_group.ssm_command.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda,
  ]

  tags = var.tags
}
