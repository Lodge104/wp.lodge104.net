locals {
  env = "prod"

  # CloudFront ALB origin read timeout (seconds); default 60.
  cloudfront_origin_read_timeout = 180

  # Serves the apex domain (lodge104.net, www., store., cdn.) in addition to
  # prod.wp.lodge104.net. Drives ACM SANs/validation zone and CDN aliases.
  serves_root_domain = true

  # CloudFront standard access logs -> prod/us-east-1/cloudfront-logs.
  cloudfront_access_logs = true

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

  # Data-protection settings (RDS deletion protection, final snapshot,
  # 30-day backups, CDN bucket force_destroy=false) default from is_prod in
  # _common/rds.hcl and _common/cdn.hcl -- set rds_* / cdn_* here only to
  # deviate from them.

  wordpress = {
    blog_name                = "Lodge104"
    replica_count            = 2
    resources_preset         = "large"
    persistence_size         = "20Gi"
    pdb_create               = true
    pod_anti_affinity_preset = "hard"
  }
}
