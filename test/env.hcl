locals {
  env = "test"

  # Environment-specific network and workload sizing.
  vpc_cidr = "10.20.0.0/16"

  eks_node_groups = {
    general = {
      min_size       = 1
      max_size       = 4
      desired_size   = 2
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
    }
  }

  rds_instances = {
    writer  = { instance_class = "db.serverless" }
    reader1 = { instance_class = "db.serverless" }
  }

  rds_scaling = {
    min_capacity = 0.5
    max_capacity = 16
  }

  elasticache = {
    num_cache_nodes = 2
    node_type       = "cache.t3.small"
  }

  wordpress = {
    blog_name                 = "Lodge104 (Test)"
    replica_count             = 2
    resources_preset          = "medium"
    persistence_size          = "10Gi"
    pdb_create                = true
    pdb_min_available         = 1
    pod_anti_affinity_preset = "hard"
  }
}
