locals {
  env = "dev"

  # Environment-specific network and workload sizing.
  vpc_cidr = "10.10.0.0/16"

  eks_node_groups = {
    general = {
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.medium"]
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

  elasticache = {
    num_cache_nodes = 1
    node_type       = "cache.t3.micro"
  }

  wordpress = {
    blog_name                 = "Lodge104 (Dev)"
    replica_count             = 2
    resources_preset          = "small"
    persistence_size          = "5Gi"
    pdb_create                = false
    pod_anti_affinity_preset = "hard"
  }
}
