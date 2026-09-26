locals {
  env = "test"

  # Environment-specific network and workload sizing.
  vpc_cidr = "10.20.0.0/16"

  eks_node_groups = {
    general = {
      min_size       = 0
      max_size       = 1
      desired_size   = 0
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
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

  elasticache = {
    num_cache_nodes      = 1
    node_type            = "cache.t3.small"
    autoscaling_max_nodes = 2
  }

  wordpress = {
    blog_name                 = "Lodge104 (Test)"
    replica_count             = 0
    resources_preset          = "medium"
    persistence_size          = "10Gi"
    pdb_create                = true
    pdb_min_available         = 0
    pod_anti_affinity_preset  = "hard"
  }
}
