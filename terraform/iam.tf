data "aws_caller_identity" "current" {}

# ── EC2 Instance Role ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "ec2" {
  name = "${var.environment}-wordpress-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Read SSM parameters in the /lodge104/ namespace and decrypt SecureStrings.
resource "aws_iam_policy" "ec2_ssm_read" {
  name        = "${var.environment}-wordpress-ssm-read"
  description = "Allow EC2 to read /lodge104/ SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "SSMParameterRead"
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters",
      ]
      Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/lodge104/*"
    }]
  })
}

# Decrypt the SecureString parameters using the default SSM KMS key.
resource "aws_iam_policy" "ec2_kms_decrypt" {
  name        = "${var.environment}-wordpress-kms-decrypt"
  description = "Allow EC2 to decrypt SSM SecureString values"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "KMSDecrypt"
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
      Resource = "*"
      Condition = {
        StringEquals = {
          "kms:ViaService" = "ssm.${var.aws_region}.amazonaws.com"
        }
      }
    }]
  })
}

# EFS client permissions scoped to the WordPress file system.
resource "aws_iam_policy" "ec2_efs" {
  name        = "${var.environment}-wordpress-efs-client"
  description = "Allow EC2 to mount the WordPress EFS volume"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EFSClient"
      Effect = "Allow"
      Action = [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite",
        "elasticfilesystem:ClientRootAccess",
        "elasticfilesystem:DescribeMountTargets",
      ]
      Resource = aws_efs_file_system.wordpress.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_ssm_read.arn
}

resource "aws_iam_role_policy_attachment" "ec2_kms_decrypt" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_kms_decrypt.arn
}

resource "aws_iam_role_policy_attachment" "ec2_efs" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_efs.arn
}

# Systems Manager — enables Session Manager (no SSH required).
resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent — publish metrics and logs.
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.environment}-wordpress-ec2-profile"
  role = aws_iam_role.ec2.name
}
