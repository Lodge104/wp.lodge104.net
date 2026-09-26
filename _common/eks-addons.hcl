# Common EKS addons (via aws-ia/eks-blueprints-addons) defaults – override in
# each env's terragrunt.hcl as needed.
locals {
  enable_aws_load_balancer_controller = true

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
