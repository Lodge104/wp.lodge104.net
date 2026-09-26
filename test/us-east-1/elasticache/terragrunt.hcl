locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/elasticache.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  region  = local.region_vars.locals.aws_region
  project = local.project_vars.locals.project_name
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

# ElastiCache does not manage Application Auto Scaling for Memcached itself
# (unlike Redis/Valkey replication groups), so the scalable target and its
# target-tracking policy are registered directly against the cache cluster.
generate "elasticache_autoscaling" {
  path      = "elasticache_autoscaling.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    resource "aws_appautoscaling_target" "memcached" {
      max_capacity       = ${local.env_vars.locals.elasticache.autoscaling_max_nodes}
      min_capacity       = ${local.env_vars.locals.elasticache.num_cache_nodes}
      resource_id        = "cache-cluster/${local.project}-${local.env}"
      scalable_dimension = "elasticache:cache-cluster:Nodes"
      service_namespace  = "elasticache"

      depends_on = [aws_elasticache_cluster.this[0]]
    }

    resource "aws_appautoscaling_policy" "memcached_cpu" {
      name               = "${local.project}-${local.env}-memcached-cpu"
      policy_type        = "TargetTrackingScaling"
      resource_id        = aws_appautoscaling_target.memcached.resource_id
      scalable_dimension = aws_appautoscaling_target.memcached.scalable_dimension
      service_namespace  = aws_appautoscaling_target.memcached.service_namespace

      target_tracking_scaling_policy_configuration {
        predefined_metric_specification {
          predefined_metric_type = "ElastiCacheEngineCPUUtilization"
        }

        target_value       = 60
        scale_in_cooldown  = 300
        scale_out_cooldown = 60
      }
    }
  EOF
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id          = "vpc-00000000000000000"
    private_subnets = ["subnet-00000000000000001", "subnet-00000000000000002", "subnet-00000000000000003"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    node_security_group_id = "sg-00000000000000001"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/elasticache/aws?version=1.3.0"
}

inputs = merge(
  local.common.locals,
  {
    cluster_id = "${local.project}-${local.env}"

    num_cache_nodes = local.env_vars.locals.elasticache.num_cache_nodes
    node_type       = local.env_vars.locals.elasticache.node_type

    subnet_ids = dependency.vpc.outputs.private_subnets
    vpc_id     = dependency.vpc.outputs.vpc_id

    security_group_rules = {
      eks_ingress = {
        description                  = "Memcached from EKS nodes"
        referenced_security_group_id = dependency.eks.outputs.node_security_group_id
      }
    }
  }
)
