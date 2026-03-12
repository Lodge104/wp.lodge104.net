packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "ami_name_prefix" {
  type    = string
  default = "lodge104-wordpress"
}

variable "subnet_id" {
  type        = string
  description = "Public subnet ID to launch the Packer build instance in. Must have a route to an IGW."
}

locals {
  timestamp = formatdate("YYYYMMDDhhmm", timestamp())
  ami_name  = "${var.ami_name_prefix}-${local.timestamp}"
}

source "amazon-ebs" "al2023" {
  region        = var.aws_region
  instance_type = var.instance_type
  ami_name      = local.ami_name

  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  ssh_username                = "ec2-user"
  associate_public_ip_address = true
  subnet_id                   = var.subnet_id

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name      = local.ami_name
    Project   = "lodge104.net"
    ManagedBy = "packer"
    BuildDate = local.timestamp
  }

  snapshot_tags = {
    Project   = "lodge104.net"
    ManagedBy = "packer"
    BuildDate = local.timestamp
  }
}

build {
  name    = "lodge104-wordpress"
  sources = ["source.amazon-ebs.al2023"]

  provisioner "shell" {
    script          = "scripts/install.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }
}
