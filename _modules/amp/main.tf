terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Amazon Managed Service for Prometheus (AMP) workspace.
# ---------------------------------------------------------------------------
resource "aws_prometheus_workspace" "this" {
  alias = var.workspace_alias
  tags  = var.tags
}

# ---------------------------------------------------------------------------
# Fully-managed AMP collector ("scraper"). This replaces the traditional
# self-managed ADOT Collector deployment -- AWS provisions, scales, and
# operates the scrape/remote-write pipeline, so there are no collector pods
# running in the cluster. The scraper connects to the EKS cluster's VPC
# directly (not through the Kubernetes API's data plane), using standard
# Prometheus Kubernetes service discovery.
#
# The source EKS cluster's authentication mode must be API or
# API_AND_CONFIG_MAP (see _common/eks.hcl / terraform-aws-modules/eks),
# and AWS automatically creates an EKS access entry granting the scraper's
# service-linked role the minimal permissions it needs
# (nodes/pods/services/endpoints get/list/watch) the first time a scraper
# for this cluster is created.
#
# Scrape target discovery is annotation-based (the long-standing Prometheus
# community convention): any Service with `prometheus.io/scrape: "true"` is
# scraped on the port named/numbered by `prometheus.io/port` (optionally
# overriding the path via `prometheus.io/path`, default "/metrics"). The
# Bitnami WordPress chart's `metrics.enabled: true` (see
# _common/wordpress.hcl) already sets these annotations on its
# apache-exporter Service, so no extra chart configuration is needed to be
# picked up here -- and any future service using the same convention is
# picked up automatically too.
# ---------------------------------------------------------------------------
resource "aws_prometheus_scraper" "this" {
  alias = var.workspace_alias

  source {
    eks {
      cluster_arn        = var.eks_cluster_arn
      subnet_ids         = var.subnet_ids
      security_group_ids = [var.eks_cluster_security_group_id]
    }
  }

  destination {
    amp {
      workspace_arn = aws_prometheus_workspace.this.arn
    }
  }

  scrape_configuration = <<-EOT
    global:
      scrape_interval: ${var.scrape_interval}
    scrape_configs:
      - job_name: kubernetes-service-endpoints
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $$1:$$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: service
  EOT

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "scraper" {
  name              = "/aws/prometheus/scraper-logs/${var.workspace_alias}"
  retention_in_days = var.log_retention_days
}

resource "aws_prometheus_scraper_logging_configuration" "this" {
  scraper_id         = aws_prometheus_scraper.this.id
  scraper_components = ["COLLECTOR", "EXPORTER", "SERVICE_DISCOVERY"]

  logging_destination {
    cloudwatch_logs {
      log_group_arn = "${aws_cloudwatch_log_group.scraper.arn}:*"
    }
  }
}
