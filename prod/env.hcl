locals {
  env = "prod"

  # Environment-specific network and workload sizing.
  vpc_cidr = "10.0.0.0/16"

  eks_node_groups = {
    general = {
      min_size     = 1
      max_size     = 10
      desired_size = 2
      # Graviton -- cheaper per-vCPU/GiB than the previous m5.xlarge (x86)
      # for the same WordPress pod resource requests. See issue #32.
      instance_types = ["m7g.large", "m6g.large"]
      capacity_type  = "ON_DEMAND"
    }
    spot = {
      min_size       = 0
      max_size       = 10
      desired_size   = 0
      instance_types = ["m7g.large", "m6g.large", "m6gd.large"]
      capacity_type  = "SPOT"
    }
  }

  rds_instances = {
    writer  = { instance_class = "db.serverless" }
    reader1 = { instance_class = "db.serverless" }
    # reader2 dropped -- moderate-HA cost optimization decision, see
    # issue #32. writer + 1 reader retained for read scale-out/failover.
  }

  rds_scaling = {
    min_capacity = 0
    # Lowered from 64 to 32 ACU to match the 2-instance (writer + 1
    # reader) topology instead of 3. See issue #32.
    max_capacity = 32
  }

  # Retained temporarily so the existing managed cache can be destroyed using
  # its original Terragrunt state key. Remove after the targeted destroy and
  # state/resource verification are complete.
  elasticache = {
    num_cache_nodes       = 1
    node_type             = "cache.r6g.large"
    autoscaling_max_nodes = 6
  }

  wordpress = {
    blog_name                = "Lodge104"
    replica_count            = 2
    resources_preset         = "large"
    persistence_size         = "20Gi"
    pdb_create               = true
    pdb_min_available        = 1
    pod_anti_affinity_preset = "hard"
  }
}
