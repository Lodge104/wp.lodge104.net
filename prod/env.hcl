locals {
  env = "prod"

  # Environment-specific network and workload sizing.
  vpc_cidr = "10.0.0.0/16"

  eks_node_groups = {
    general = {
      min_size       = 2
      max_size       = 10
      desired_size   = 3
      instance_types = ["m5.xlarge"]
      capacity_type  = "ON_DEMAND"
    }
    spot = {
      min_size       = 0
      max_size       = 10
      desired_size   = 0
      instance_types = ["m5.xlarge", "m5a.xlarge", "m4.xlarge"]
      capacity_type  = "SPOT"
    }
  }

  rds_instances = {
    writer  = { instance_class = "db.serverless" }
    reader1 = { instance_class = "db.serverless" }
    reader2 = { instance_class = "db.serverless" }
  }

  rds_scaling = {
    min_capacity = 1
    max_capacity = 64
  }

  elasticache = {
    num_cache_nodes = 3
    node_type       = "cache.r6g.large"
  }

  wordpress = {
    blog_name       = "Lodge104"
    replica_count   = 3
    resources_preset = "large"
    persistence_size = "20Gi"
    pdb_create      = true
    pdb_min_available = 2
    pod_anti_affinity_preset = "hard"
  }
}
