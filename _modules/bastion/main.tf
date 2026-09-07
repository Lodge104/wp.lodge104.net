terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  env_vpc_names = [for env in var.environment_names : "${var.project_name}-${env}"]

  existing_vpcs_by_name = {
    for vpc in data.aws_vpc.discovered :
    vpc.tags.Name => {
      id         = vpc.id
      cidr_block = vpc.cidr_block
    }
    if contains(local.env_vpc_names, try(vpc.tags.Name, ""))
  }

  preferred_bastion_vpc_name = try(
    [for name in [for env in var.bastion_home_env_preference : "${var.project_name}-${env}"] : name if contains(keys(local.existing_vpcs_by_name), name)][0],
    null
  )

  bastion_vpc_id         = try(local.existing_vpcs_by_name[local.preferred_bastion_vpc_name].id, null)
  bastion_vpc_cidr_block = try(local.existing_vpcs_by_name[local.preferred_bastion_vpc_name].cidr_block, null)

  bastion_subnet_ids = local.bastion_vpc_id == null ? [] : sort(data.aws_subnets.bastion_private[0].ids)
  create_bastion     = local.bastion_vpc_id != null && length(local.bastion_subnet_ids) > 0

  peer_vpcs = {
    for name, vpc in local.existing_vpcs_by_name :
    name => vpc if local.create_bastion && vpc.id != local.bastion_vpc_id
  }

  existing_cluster_identifiers = toset(try(data.aws_rds_clusters.all.cluster_identifiers, []))
  target_cluster_identifiers   = toset([for env in var.environment_names : "${var.project_name}-${env}"])

  selected_cluster_identifiers = toset([
    for id in local.target_cluster_identifiers : id
    if contains(local.existing_cluster_identifiers, id)
  ])

  rds_security_group_ids = toset(flatten([
    for cluster in data.aws_rds_cluster.selected : cluster.vpc_security_group_ids
  ]))

  target_efs_tokens = toset([for env in var.environment_names : "${var.project_name}-${env}"])

  selected_efs = {
    for fs in data.aws_efs_file_system.by_id :
    fs.creation_token => fs if contains(local.target_efs_tokens, fs.creation_token)
  }

  efs_mount_descriptors = [
    for token in sort(keys(local.selected_efs)) : {
      token = token
      id    = local.selected_efs[token].id
    }
  ]

  efs_security_group_ids = local.create_bastion ? toset(data.aws_security_groups.efs[0].ids) : toset([])

  common_tags = merge(
    {
      Name = "${var.project_name}-bastion"
    },
    var.tags,
  )

  peer_route_specs = flatten([
    for vpc_name, vpc in local.peer_vpcs : [
      for route_table_id in try(data.aws_route_tables.by_vpc[vpc_name].ids, []) : {
        key            = "${vpc_name}:${route_table_id}"
        route_table_id = route_table_id
        destination    = local.bastion_vpc_cidr_block
        peer_vpc_name  = vpc_name
      }
    ]
  ])

  bastion_route_specs = flatten([
    for vpc_name, vpc in local.peer_vpcs : [
      for route_table_id in try(data.aws_route_tables.bastion[0].ids, []) : {
        key            = "${vpc_name}:${route_table_id}"
        route_table_id = route_table_id
        destination    = vpc.cidr_block
        peer_vpc_name  = vpc_name
      }
    ]
  ])
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_vpcs" "env" {
  filter {
    name   = "tag:Name"
    values = local.env_vpc_names
  }
}

data "aws_vpc" "discovered" {
  for_each = toset(data.aws_vpcs.env.ids)
  id       = each.value
}

data "aws_subnets" "bastion_private" {
  count = local.bastion_vpc_id == null ? 0 : 1

  filter {
    name   = "vpc-id"
    values = [local.bastion_vpc_id]
  }

  filter {
    name   = "tag:kubernetes.io/role/internal-elb"
    values = ["1"]
  }
}

data "aws_route_tables" "bastion" {
  count = local.bastion_vpc_id == null ? 0 : 1

  vpc_id = local.bastion_vpc_id
}

data "aws_route_tables" "by_vpc" {
  for_each = local.peer_vpcs

  vpc_id = each.value.id
}

data "aws_rds_clusters" "all" {}

data "aws_rds_cluster" "selected" {
  for_each = { for id in local.selected_cluster_identifiers : id => id }

  cluster_identifier = each.value
}

data "aws_resourcegroupstaggingapi_resources" "efs" {
  resource_type_filters = ["elasticfilesystem:file-system"]
}

data "aws_efs_file_system" "by_id" {
  for_each = toset([
    for mapping in data.aws_resourcegroupstaggingapi_resources.efs.resource_tag_mapping_list :
    regex("file-system/(fs-[0-9a-f]+)$", mapping.resource_arn)[0]
  ])

  file_system_id = each.value
}

data "aws_security_groups" "efs" {
  count = local.create_bastion ? 1 : 0

  filter {
    name   = "group-name"
    values = [for env in var.environment_names : "${var.project_name}-${env}-efs"]
  }

  filter {
    name   = "vpc-id"
    values = values(local.existing_vpcs_by_name)[*].id
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "bastion_access" {
  statement {
    sid    = "AllowSsmSessionManager"
    effect = "Allow"
    actions = [
      "ssm:UpdateInstanceInformation",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowReadProjectSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}:*:secret:${var.project_name}-*",
    ]
  }

  statement {
    sid       = "AllowListSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:ListSecrets"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowTransferBucketAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.transfer_bucket_name}",
    ]
  }

  statement {
    sid    = "AllowTransferBucketObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = [
      "arn:aws:s3:::${var.transfer_bucket_name}/*",
    ]
  }
}

resource "aws_security_group" "bastion" {
  count = local.create_bastion ? 1 : 0

  name        = "${var.project_name}-bastion"
  description = "SSM-only bastion"
  vpc_id      = local.bastion_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_iam_role" "bastion" {
  count = local.create_bastion ? 1 : 0

  name               = "${var.project_name}-bastion"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  count = local.create_bastion ? 1 : 0

  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "bastion_access" {
  count = local.create_bastion ? 1 : 0

  name   = "${var.project_name}-bastion-access"
  role   = aws_iam_role.bastion[0].id
  policy = data.aws_iam_policy_document.bastion_access.json
}

resource "aws_iam_instance_profile" "bastion" {
  count = local.create_bastion ? 1 : 0

  name = "${var.project_name}-bastion"
  role = aws_iam_role.bastion[0].name

  tags = local.common_tags
}

resource "aws_instance" "bastion" {
  count = local.create_bastion ? 1 : 0

  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = local.bastion_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.bastion[0].id]
  iam_instance_profile        = aws_iam_instance_profile.bastion[0].name
  user_data_replace_on_change = true

  associate_public_ip_address = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = false
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    # An SSM association installs AmazonEFSUtils via dnf independently at boot,
    # which races with this script's dnf transaction and can corrupt the cache.
    for i in $(seq 1 10); do
      dnf clean packages
      if dnf install -y amazon-efs-utils nfs-utils mariadb1011 jq unzip; then
        break
      fi
      echo "dnf install attempt $i failed, retrying in 10s..."
      sleep 10
    done

    mkdir -p /mnt/efs

    cat > /usr/local/bin/mount-env-efs.sh <<'EOT'
    #!/bin/bash
    set -euo pipefail

    %{for fs in local.efs_mount_descriptors~}
    mkdir -p /mnt/efs/${fs.token}
    if ! grep -q "${fs.id}:/ /mnt/efs/${fs.token} efs" /etc/fstab; then
      echo "${fs.id}:/ /mnt/efs/${fs.token} efs _netdev,tls,noresvport 0 0" >> /etc/fstab
    fi
    %{endfor~}

    mount -a -t efs || true
    EOT

    chmod +x /usr/local/bin/mount-env-efs.sh
    /usr/local/bin/mount-env-efs.sh
  EOF

  tags = local.common_tags
}

resource "aws_vpc_peering_connection" "env" {
  for_each = local.peer_vpcs

  peer_vpc_id = each.value.id
  vpc_id      = local.bastion_vpc_id
  auto_accept = true

  tags = merge(local.common_tags, { Name = "${var.project_name}-bastion-to-${each.key}" })
}

resource "aws_route" "bastion_to_peer" {
  for_each = {
    for route in local.bastion_route_specs : route.key => route
  }

  route_table_id            = each.value.route_table_id
  destination_cidr_block    = each.value.destination
  vpc_peering_connection_id = aws_vpc_peering_connection.env[each.value.peer_vpc_name].id
}

resource "aws_route" "peer_to_bastion" {
  for_each = {
    for route in local.peer_route_specs : route.key => route
  }

  route_table_id            = each.value.route_table_id
  destination_cidr_block    = each.value.destination
  vpc_peering_connection_id = aws_vpc_peering_connection.env[each.value.peer_vpc_name].id
}

resource "aws_security_group_rule" "rds_from_bastion_vpc" {
  for_each = local.create_bastion ? {
    for sg_id in local.rds_security_group_ids : sg_id => sg_id
  } : {}

  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id        = each.value
  source_security_group_id = aws_security_group.bastion[0].id
  description              = "MySQL from bastion"

  depends_on = [aws_vpc_peering_connection.env]
}

resource "aws_security_group_rule" "efs_from_bastion_vpc" {
  for_each = local.create_bastion ? {
    for sg_id in local.efs_security_group_ids : sg_id => sg_id
  } : {}

  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  security_group_id = each.value
  cidr_blocks       = [local.bastion_vpc_cidr_block]
  description       = "NFS from bastion VPC"
}
