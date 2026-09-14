# Common EKS addons (via aws-ia/eks-blueprints-addons) defaults – override in
# each env's terragrunt.hcl as needed.
locals {
  enable_aws_load_balancer_controller = true

  # Lets workload pods (e.g. WordPress) read AWS Secrets Manager secrets
  # directly via EKS Pod Identity, mounted/synced through a
  # SecretProviderClass instead of static Terraform-managed Secret snapshots.
  enable_secrets_store_csi_driver              = true
  enable_secrets_store_csi_driver_provider_aws = true
}
