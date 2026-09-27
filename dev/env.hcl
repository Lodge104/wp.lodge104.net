locals {
  env = "dev"

  # Environment-specific network and workload sizing.
  vpc_cidr = "10.10.0.0/16"

  eks_node_groups = {
    general = {
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      # Graviton -- matches the arm64 AMI default in _common/eks.hcl. See
      # issue #32.
      instance_types = ["t4g.medium"]
      capacity_type  = "SPOT"
    }
  }

  rds_instances = {
    writer = { instance_class = "db.serverless" }
  }

  rds_scaling = {
    min_capacity             = 0
    max_capacity             = 4
    seconds_until_auto_pause = 300
  }

  # ElastiCache block removed -- WordPress now uses the in-cluster
  # Memcached sub-chart instead of the managed ElastiCache service. See
  # issue #32.

  wordpress = {
    blog_name                 = "Lodge104 (Dev)"
    replica_count             = 2
    resources_preset          = "small"
    persistence_size          = "5Gi"
    pdb_create                = false
    pod_anti_affinity_preset  = "hard"
  }
}
