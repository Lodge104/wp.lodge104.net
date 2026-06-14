terraform {
  required_providers {
    # AWS provider is declared by the root Terragrunt-generated provider.tf.
    # Only the Helm provider needs to be added here.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
  }
}

# Look up the EKS cluster to configure the Helm provider dynamically.
# This avoids needing to pass the endpoint / CA data as variables.
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    }
  }
}

resource "helm_release" "this" {
  name             = var.release_name
  repository       = var.repository
  chart            = var.chart
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = var.create_namespace
  timeout          = var.timeout
  wait             = var.wait
  atomic           = var.atomic

  dynamic "set" {
    for_each = var.set_values
    content {
      name  = set.value.name
      value = set.value.value
    }
  }

  values = var.values
}
