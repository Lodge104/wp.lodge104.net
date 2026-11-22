# -----------------------------------------------------------------------------
# Shared environment helper (issue #45 / #47)
#
# Resolves the env / region / project context of the stack that is being
# evaluated and exposes it as plain locals, so neither stack shims nor
# _common/<stack>.hcl fragments need the usual env_vars / region_vars /
# project_vars boilerplate.
#
# Usage (from a stack terragrunt.hcl OR from an included _common/<stack>.hcl):
#
#   locals {
#     ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
#   }
#   inputs = { name = local.ctx.name }
#
# Why not find_in_parent_folders()?
#   Inside a file loaded with read_terragrunt_config(), find_in_parent_folders()
#   and get_terragrunt_dir() resolve relative to THIS file (_common/), not the
#   stack, so they would never find <env>/env.hcl. get_original_terragrunt_dir()
#   points at the stack directory being run (also when this helper is read
#   from an included _common/<stack>.hcl), so the parent-folder walk below is
#   done explicitly from there. The nearest file wins, matching
#   find_in_parent_folders() semantics. Verified on Terragrunt v1.1.6 by
#   scripts/verify-env-helper.sh.
#
# Note: Terragrunt only supports one level of `include`, so this helper must be
# consumed with read_terragrunt_config(), never with an `include` block.
# -----------------------------------------------------------------------------

locals {
  repo_root = get_repo_root()
  stack_dir = get_original_terragrunt_dir()

  # Stack path relative to the repo root, e.g. "dev/us-east-1/vpc" or
  # "global/route53-dev".
  stack_path  = trimprefix(local.stack_dir, "${local.repo_root}/")
  stack_parts = split("/", local.stack_path)
  stack_name  = basename(local.stack_dir)
  is_global   = local.stack_parts[0] == "global"

  # Parent directories of the stack, nearest first, ending with the repo root.
  search_dirs = concat(
    [
      for i in range(length(local.stack_parts) - 1, 0, -1) :
      join("/", concat([local.repo_root], slice(local.stack_parts, 0, i)))
    ],
    [local.repo_root],
  )

  env_files     = [for d in local.search_dirs : "${d}/env.hcl" if fileexists("${d}/env.hcl")]
  region_files  = [for d in local.search_dirs : "${d}/region.hcl" if fileexists("${d}/region.hcl")]
  project_files = [for d in local.search_dirs : "${d}/project.hcl" if fileexists("${d}/project.hcl")]

  # Locals of the nearest env.hcl / region.hcl / project.hcl ({} when absent,
  # e.g. global/ has no env.hcl). merge() over a 0- or 1-element list avoids
  # HCL's "inconsistent conditional result types" error.
  env_vars     = merge({}, [for f in slice(local.env_files, 0, min(1, length(local.env_files))) : read_terragrunt_config(f).locals]...)
  region_vars  = merge({}, [for f in slice(local.region_files, 0, min(1, length(local.region_files))) : read_terragrunt_config(f).locals]...)
  project_vars = merge({}, [for f in slice(local.project_files, 0, min(1, length(local.project_files))) : read_terragrunt_config(f).locals]...)

  # ---------------------------------------------------------------------------
  # Derived values – the public interface of this helper.
  # ---------------------------------------------------------------------------
  project = local.project_vars.project_name
  domain  = local.project_vars.domain
  region  = local.region_vars.aws_region

  # Env stacks must have an env.hcl; global stacks default to "global".
  env = local.is_global ? try(local.env_vars.env, "global") : local.env_vars.env

  # Canonical resource name prefix, e.g. "net-lodge104-wp-dev".
  name = "${local.project}-${local.env}"

  is_prod = try(local.env_vars.is_prod, local.env == "prod")

  # Per-env delegated zone / hostname, e.g. "dev.wp.lodge104.net" (null in
  # global/, where stacks are not tied to a single env).
  env_domain = local.is_global ? null : "${local.env}.wp.${local.domain}"

  alb_hosted_zone_id = try(local.region_vars.alb_hosted_zone_id, null)

  # Standard mock policy for dependency blocks.
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}
