# Common EKS addons (via aws-ia/eks-blueprints-addons) defaults – override in
# each env's terragrunt.hcl as needed.
locals {
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
  # group in */us-east-1/eks/terragrunt.hcl for ASG auto-discovery.
  enable_cluster_autoscaler = true

  # The chart defaults image.tag to match the cluster's Kubernetes minor
  # version (cluster_version = "1.37" in _common/eks.hcl), but upstream
  # cluster-autoscaler releases lag behind new Kubernetes minor versions --
  # there is no v1.37.0 image published yet, only up to v1.36.1 as of
  # 2026-10-18 (https://github.com/kubernetes/autoscaler/releases). Pin to
  # the latest actually-published version; cluster-autoscaler is documented
  # as compatible with a cluster up to one minor version ahead of its own.
  # Bump this once a v1.37.x image exists upstream.
  cluster_autoscaler = {
    set = [
      {
        name  = "image.tag"
        value = "v1.36.1"
      }
    ]
  }

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
