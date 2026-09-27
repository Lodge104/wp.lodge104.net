locals {
  env = "test"

  # Environment-specific network and workload sizing.
  vpc_cidr = "10.20.0.0/16"

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
    writer  = { instance_class = "db.serverless" }
    reader1 = { instance_class = "db.serverless" }
  }

  rds_scaling = {
    min_capacity = 0
    max_capacity = 16
  }

  # ElastiCache block removed -- WordPress now uses the in-cluster
  # Memcached sub-chart instead of the managed ElastiCache service. See
  # issue #32.

  wordpress = {
    blog_name                 = "Lodge104 (Test)"
    replica_count             = 2
    resources_preset          = "medium"
    # Matches the existing bound PVC. Kubernetes can't shrink a bound PVC, so
    # this can only go up. On EFS the size isn't enforced and doesn't affect cost.
    persistence_size          = "20Gi"
    pdb_create                = true
    pdb_min_available         = 1
    pod_anti_affinity_preset  = "hard"
  }
}
