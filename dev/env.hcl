locals {
  env = "dev"

  # Environment-specific network and workload sizing.
  vpc_cidr = "10.10.0.0/16"

  eks_node_groups = {
    general = {
      min_size     = 2
      max_size     = 3
      desired_size = 2
      # Graviton -- matches the arm64 AMI default in _common/eks.hcl. See
      # issue #32.
      instance_types = ["t4g.medium"]
      capacity_type  = "SPOT"
    }
  }

  # No Cluster Autoscaler ASG discovery tags on dev's node groups.
  eks_cluster_autoscaler_tags = false

  rds_instances = {
    writer = { instance_class = "db.serverless" }
  }

  rds_scaling = {
    min_capacity             = 0
    max_capacity             = 4
    seconds_until_auto_pause = 300
  }

  # Dev has no destroy-time final-snapshot hook (skip_final_snapshot only).
  rds_destroy_snapshot_hook = false

  # Dev's uploads CDN uses the module's default OAC name ("cdn") rather than
  # "cdn-dev". Renaming would replace the OAC.
  cdn_origin_access_control_name = null

  # ElastiCache block removed -- WordPress now uses the in-cluster
  # Memcached sub-chart instead of the managed ElastiCache service. See
  # issue #32.

  wordpress = {
    blog_name                = "Lodge104 (Dev)"
    replica_count            = 2
    resources_preset         = "small"
    persistence_size         = "5Gi"
    pdb_create               = false
    pod_anti_affinity_preset = "hard"

    # Dev is the lean env: no HPA, no explicit resource requests/limits, no
    # apex-domain handling (redirect / ingress hosts), chart-default install
    # behavior, module-default helm timeout and immediate admin-secret
    # deletion on destroy. The .well-known postStart hook raced the
    # entrypoint's first-boot install on fresh/empty PVCs here.
    wellknown_hook                       = false
    hpa_enabled                          = false
    resource_limits                      = false
    www_redirect                         = false
    root_domain_ingress_hosts            = false
    skip_install                         = null
    helm_timeout                         = null
    admin_secret_recovery_window_in_days = null
  }
}
