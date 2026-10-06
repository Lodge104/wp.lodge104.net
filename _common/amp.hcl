# Common Amazon Managed Service for Prometheus (AMP) defaults -- override in
# each env's terragrunt.hcl as needed.
#
# Uses the fully-managed AMP collector ("scraper") introduced in 2026 instead
# of a self-managed ADOT Collector deployment: AWS provisions, scales, and
# operates the scrape + remote-write pipeline directly against the EKS
# cluster's VPC, so there are no collector pods, IAM roles for service
# accounts, or Pod Identity associations to manage in-cluster. See
# _modules/amp.
locals {
  scrape_interval     = "30s"
  log_retention_days  = 14
}
