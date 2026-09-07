terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
  }
}

# ---------------------------------------------------------------------------
# EFS file system
# ---------------------------------------------------------------------------
resource "aws_efs_file_system" "this" {
  creation_token   = var.name
  encrypted        = true
  throughput_mode  = var.throughput_mode
  performance_mode = var.performance_mode

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = var.name
  }
}

# ---------------------------------------------------------------------------
# Mount targets – one per private subnet
# ---------------------------------------------------------------------------
resource "aws_efs_mount_target" "this" {
  for_each = toset(var.subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

# ---------------------------------------------------------------------------
# Security group – allow NFS from the EKS node SG
# ---------------------------------------------------------------------------
resource "aws_security_group" "efs" {
  name        = "${var.name}-efs"
  description = "Allow NFS traffic from EKS nodes to EFS"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-efs"
  }
}

resource "aws_security_group_rule" "nfs_from_eks_nodes" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = var.eks_node_security_group_id
  description              = "NFS from EKS nodes"
}

# ---------------------------------------------------------------------------
# Kubernetes StorageClass – created via the kubernetes provider so Helm can
# reference it without a separate kubectl apply step.
# ---------------------------------------------------------------------------
data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = ["eks", "get-token", "--region", var.region, "--cluster-name", var.eks_cluster_name]
  }
}

resource "kubernetes_storage_class_v1" "efs_sc" {
  metadata {
    name = "efs-sc"
  }

  storage_provisioner    = "efs.csi.aws.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = false

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.this.id
    directoryPerms   = "777"
  }
}

# ---------------------------------------------------------------------------
# IAM role for the aws-efs-csi-driver addon, granted via EKS Pod Identity.
# The addon's controller pods (service account "efs-csi-controller-sa" in
# kube-system) otherwise have no AWS credentials and fail to call the EFS API
# ("no EC2 IMDS role found") when provisioning access points.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "efs_csi_pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "efs_csi" {
  name               = "${var.name}-efs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.efs_csi_pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  role       = aws_iam_role.efs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

resource "aws_eks_pod_identity_association" "efs_csi" {
  cluster_name    = var.eks_cluster_name
  namespace       = "kube-system"
  service_account = "efs-csi-controller-sa"
  role_arn        = aws_iam_role.efs_csi.arn
}

# ---------------------------------------------------------------------------
# Restart the EFS CSI driver controller after the Pod Identity association is
# created or updated. The EKS managed addon is created by the cluster module,
# which runs before this module, so the controller pods may already be running
# without credentials when the association is finally created. A rollout
# restart forces the pods to re-inject the Pod Identity credentials so they
# can provision access points for PVCs backed by the efs-sc StorageClass.
# ---------------------------------------------------------------------------
resource "terraform_data" "efs_csi_controller_restart" {
  triggers_replace = [
    aws_eks_pod_identity_association.efs_csi.id,
    aws_eks_pod_identity_association.efs_csi.role_arn,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      KUBECONFIG=$(mktemp)
      export KUBECONFIG
      trap 'rm -f "$KUBECONFIG"' EXIT
      aws eks update-kubeconfig --name "${var.eks_cluster_name}" --region "${var.region}" >/dev/null

      if kubectl get deployment efs-csi-controller -n kube-system >/dev/null 2>&1; then
        echo "Restarting efs-csi-controller to pick up Pod Identity credentials..."
        kubectl rollout restart deployment efs-csi-controller -n kube-system
        # Block until the new pods are actually Ready, otherwise downstream
        # modules (e.g. wordpress) can start creating PVCs while the
        # controller is still mid-rollout and has no credentials yet,
        # causing "unbound immediate PersistentVolumeClaims" errors.
        kubectl rollout status deployment efs-csi-controller -n kube-system --timeout=180s
      else
        echo "efs-csi-controller deployment not found; skipping restart."
      fi
    EOT
  }

  depends_on = [aws_eks_pod_identity_association.efs_csi]
}
