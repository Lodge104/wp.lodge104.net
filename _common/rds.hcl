# -----------------------------------------------------------------------------
# rds – Aurora MySQL Serverless v2 cluster.
#
# Env-level knobs (<env>/env.hcl):
#   rds_instances                 map of cluster instances
#   rds_scaling                   serverlessv2_scaling_configuration
#   rds_deletion_protection       default: is_prod
#   rds_final_snapshot            take a final snapshot on destroy
#                                 (default: is_prod)
#   rds_backup_retention_period   default: 30 in prod, 7 otherwise
#
# database_name / master_username live in _common/shared/rds.hcl so other
# stacks (wordpress) can read them.
#
# Full Terragrunt fragment included by <env>/<region>/rds/terragrunt.hcl. Env
# shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx    = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  shared = read_terragrunt_config("${get_repo_root()}/_common/shared/rds.hcl").locals
  env    = local.ctx.env_vars

  deletion_protection     = try(local.env.rds_deletion_protection, local.ctx.is_prod)
  final_snapshot          = try(local.env.rds_final_snapshot, local.ctx.is_prod)
  backup_retention_period = try(local.env.rds_backup_retention_period, local.ctx.is_prod ? 30 : 7)

  # Timestamped so repeat teardowns don't collide with an earlier final
  # snapshot (DBClusterSnapshotAlreadyExistsFault).
  timestamped_final_snapshot_identifier = "${local.ctx.name}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  # Snapshot inputs as they were per env before #45, kept byte-identical so the
  # conversion is a no-op:
  #   final_snapshot = true  (prod): stable identifier, snapshot kept.
  #   final_snapshot = false (test): timestamped identifier, snapshot skipped.
  #   dev predates the destroy hook and passes no identifier at all
  #   (rds_destroy_snapshot_hook = false in dev/env.hcl).
  # TODO(#45 cleanup): the timestamped identifier in `inputs` shows a
  # perpetual in-place diff on aws_rds_cluster.final_snapshot_identifier in
  # test (pre-existing); passing it only via the destroy extra_arguments
  # below would remove that drift.
  destroy_snapshot_hook = try(local.env.rds_destroy_snapshot_hook, true)
  snapshot_inputs = merge(
    { skip_final_snapshot = !local.final_snapshot },
    local.final_snapshot ? { final_snapshot_identifier = "${local.ctx.name}-final" } : {},
    !local.final_snapshot && local.destroy_snapshot_hook ? { final_snapshot_identifier = local.timestamped_final_snapshot_identifier } : {},
  )
}

terraform {
  source = "tfr:///terraform-aws-modules/rds-aurora/aws?version=9.3.0"

  # Destroy-time final-snapshot hook. Disabled (no commands) when
  # rds_destroy_snapshot_hook = false.
  extra_arguments "final_snapshot" {
    commands = local.destroy_snapshot_hook ? ["destroy"] : []
    arguments = [
      "-var=final_snapshot_identifier=${local.timestamped_final_snapshot_identifier}",
      "-var=skip_final_snapshot=${!local.final_snapshot}",
    ]
  }
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id          = "vpc-00000000000000000"
    private_subnets = ["subnet-00000000000000001", "subnet-00000000000000002", "subnet-00000000000000003"]
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    node_security_group_id = "sg-00000000000000001"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = merge(
  {
    name = local.ctx.name

    engine         = "aurora-mysql"
    engine_version = "8.0.mysql_aurora.3.10.3"
    engine_mode    = "provisioned" # Serverless v2 uses provisioned mode with db.serverless instances
    # family / major_engine_version are not variables of rds-aurora 9.x; kept
    # so the rendered inputs are unchanged. Remove in the #45 cleanup phase.
    family               = "aurora-mysql8.0"
    major_engine_version = "8.0"

    port          = 3306
    database_name = local.shared.database_name

    # Credentials remain managed by AWS Secrets Manager, but rotation is
    # disabled so consumers that sync this secret into Kubernetes do not drift.
    master_username                      = local.shared.master_username
    manage_master_user_password          = true
    manage_master_user_password_rotation = false

    preferred_backup_window      = "03:00-06:00"
    preferred_maintenance_window = "mon:00:00-mon:03:00"

    enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

    # Enhanced monitoring disabled -- its per-instance CloudWatch cost wasn't
    # justified by active use. Performance Insights (free tier: 7-day
    # retention) remains enabled for query-level diagnostics.
    create_monitoring_role = false
    monitoring_interval    = 0

    performance_insights_enabled = true
    # Kept at the free-tier 7 days in every env (prod previously used 731) --
    # cost optimization, see issue #32.
    performance_insights_retention_period = 7

    auto_minor_version_upgrade = true
    apply_immediately          = false

    # Serverless v2 requires at least one instance of class db.serverless.
    instance_class                     = "db.serverless"
    instances                          = local.env.rds_instances
    serverlessv2_scaling_configuration = local.env.rds_scaling

    # Module defaults create_db_subnet_group to false (expects an existing
    # group); we want it created from the subnets/vpc_id we pass in.
    create_db_subnet_group = true
    db_subnet_group_name   = local.ctx.name
    subnets                = dependency.vpc.outputs.private_subnets
    vpc_id                 = dependency.vpc.outputs.vpc_id
    vpc_security_group_ids = []

    security_group_rules = {
      eks_ingress = {
        description              = "MySQL from EKS nodes"
        source_security_group_id = dependency.eks.outputs.node_security_group_id
      }
    }

    deletion_protection     = local.deletion_protection
    backup_retention_period = local.backup_retention_period
  },
  local.snapshot_inputs,
)
