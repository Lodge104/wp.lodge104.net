# -----------------------------------------------------------------------------
# eks-addons – cluster add-ons via aws-ia/eks-blueprints-addons (AWS Load
# Balancer Controller, metrics-server, Secrets Store CSI driver, ...) plus the
# Amazon CloudWatch Observability managed add-on.
#
# Full Terragrunt fragment included by <env>/<region>/eks-addons/
# terragrunt.hcl. Env shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx    = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  shared = read_terragrunt_config("${get_repo_root()}/_common/shared/eks.hcl").locals

  # Module inputs shared by every env (merged into `inputs` below).
  defaults = {
    enable_aws_load_balancer_controller = true

    # Required for the wordpress chart's HPA (autoscaling.enabled in
    # _common/wordpress.hcl) to read cpu/memory utilization. Without this the
    # HPA sits at <unknown>/target and never scales out, so wordpress is stuck
    # at its static replicaCount even under memory pressure. See prod outage
    # postmortem (2026-10-12).
    enable_metrics_server = true

    # The wordpress HPA can scale up to 10 replicas, but
    # wordpress.podAntiAffinityPreset is "hard" (requiredDuringScheduling), so
    # at most one wordpress pod can land per node. With a static node count
    # and nothing reacting to unschedulable pods, HPA scale-outs beyond the
    # node count just sit in FailedScheduling ("didn't match pod anti-affinity
    # rules") until HPA scales back down -- autoscaling never actually added
    # capacity. Cluster Autoscaler watches for exactly this (pending pods it
    # can resolve by adding a node) and scales the node group's ASG up to its
    # max_size, using the k8s.io/cluster-autoscaler/* tags added to each node
    # group in _common/eks.hcl for ASG auto-discovery.
    # Upstream recommends matching the Cluster Autoscaler and Kubernetes minor
    # versions; cross-version compatibility is not tested. Keep it disabled
    # until a published release matching the cluster version is available.
    enable_cluster_autoscaler = false

    # Lets workload pods (e.g. WordPress) read AWS Secrets Manager secrets
    # directly via EKS Pod Identity, mounted/synced through a
    # SecretProviderClass instead of static Terraform-managed Secret snapshots.
    enable_secrets_store_csi_driver              = true
    enable_secrets_store_csi_driver_provider_aws = true

    # The module's default core driver chart (1.4.1) uses an older
    # providerVolumePath convention that doesn't match the AWS provider
    # chart's current socket path default, causing "no such file or
    # directory" mount failures. Pin both to versions known to match (per the
    # provider chart's own release notes).
    secrets_store_csi_driver = {
      chart_version = "1.6.0"
      values = [
        yamlencode({
          tokenRequests = [
            { audience = "pods.eks.amazonaws.com" }
          ]
          # Required for SecretProviderClass.secretObjects to sync mounted
          # secrets into Kubernetes Secrets; grants the driver RBAC to
          # list/watch/create/update Secrets.
          syncSecret = {
            enabled = true
          }
          enableSecretRotation = true
          rotationPollInterval = "2m"
        })
      ]
    }

    # The module's default provider chart (0.3.6) predates EKS Pod Identity
    # support (added ~2.1.0+), causing "An IAM role must be associated with
    # service account" errors even with usePodIdentity: "true" set. Newer
    # provider chart versions bundle the core driver as a subchart by default,
    # which conflicts with the separately-managed secrets_store_csi_driver
    # release above, so that bundled install is disabled here.
    secrets_store_csi_driver_provider_aws = {
      chart_version = "3.1.3"
      values = [
        yamlencode({
          "secrets-store-csi-driver" = {
            install = false
          }
        })
      ]
    }
  }
}

terraform {
  source = "tfr:///aws-ia/eks-blueprints-addons/aws?version=1.24.3"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name                       = local.ctx.name
    cluster_endpoint                   = "https://example.eks.amazonaws.com"
    cluster_certificate_authority_data = base64encode(file("${get_repo_root()}/_common/mock-ca.pem"))
    cluster_version                    = local.shared.kubernetes_version
    oidc_provider_arn                  = "arn:aws:iam::000000000000:oidc-provider/oidc.eks.${local.ctx.region}.amazonaws.com/id/00000000000000000000000000000000"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# Generate the Helm/Kubernetes provider configuration as a root-module file.
# Providers must not be declared inside reusable child modules.
generate "helm_provider" {
  path      = "helm_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "helm" {
      kubernetes = {
        host                   = "${dependency.eks.outputs.cluster_endpoint}"
        cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

        exec = {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.ctx.region}"]
        }
      }
    }

    provider "kubernetes" {
      host                   = "${dependency.eks.outputs.cluster_endpoint}"
      cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.ctx.region}"]
      }
    }
  EOF
}

# Amazon CloudWatch Observability isn't supported by the aws-ia/eks-blueprints-addons
# module (it only wraps Helm-chart addons + a generic eks_addons map that doesn't thread
# through pod_identity_association), so it's created directly here as a managed EKS addon.
# Installed via EKS Pod Identity (the recommended method, supported since addon v3.1.0+)
# so logs/metrics survive pod deletion -- this is what lets us read WordPress crash logs in
# CloudWatch Logs Insights after Helm's atomic rollback deletes a failed pod.
generate "cloudwatch_observability_addon" {
  path      = "cloudwatch_observability_addon.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    data "aws_eks_addon_version" "cloudwatch_observability" {
      addon_name         = "amazon-cloudwatch-observability"
      kubernetes_version = "${dependency.eks.outputs.cluster_version}"
      most_recent        = true
    }

    resource "aws_iam_role" "cloudwatch_observability" {
      name = "${dependency.eks.outputs.cluster_name}-cloudwatch-observability"

      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = { Service = "pods.eks.amazonaws.com" }
          Action    = ["sts:AssumeRole", "sts:TagSession"]
        }]
      })
    }

    resource "aws_iam_role_policy_attachment" "cloudwatch_observability_agent" {
      role       = aws_iam_role.cloudwatch_observability.name
      policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    }

    resource "aws_iam_role_policy_attachment" "cloudwatch_observability_xray" {
      role       = aws_iam_role.cloudwatch_observability.name
      policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
    }

    resource "aws_eks_addon" "cloudwatch_observability" {
      cluster_name  = "${dependency.eks.outputs.cluster_name}"
      addon_name    = "amazon-cloudwatch-observability"
      addon_version = data.aws_eks_addon_version.cloudwatch_observability.version

      pod_identity_association {
        role_arn        = aws_iam_role.cloudwatch_observability.arn
        service_account = "cloudwatch-agent"
      }

      depends_on = [
        aws_iam_role_policy_attachment.cloudwatch_observability_agent,
        aws_iam_role_policy_attachment.cloudwatch_observability_xray,
      ]
    }
  EOF
}

inputs = merge(
  local.defaults,
  {
    cluster_name      = dependency.eks.outputs.cluster_name
    cluster_endpoint  = dependency.eks.outputs.cluster_endpoint
    cluster_version   = dependency.eks.outputs.cluster_version
    oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn

    # EC2 metadata-based VPC auto-discovery fails for the controller, so pass
    # the VPC ID explicitly via helm values.
    aws_load_balancer_controller = {
      wait = true
      set = [
        {
          name  = "vpcId"
          value = dependency.vpc.outputs.vpc_id
        }
      ]
    }
  }
)
