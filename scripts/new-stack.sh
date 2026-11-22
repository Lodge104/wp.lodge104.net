#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Scaffolds a new Terragrunt stack following the #45 layout:
#   - _common/<stack>.hcl   full fragment (source, dependencies, inputs)
#   - <env>/<region>/<stack>/terragrunt.hcl (or global/<stack>/terragrunt.hcl)
#     thin shims including root.hcl + the fragment
#
# Usage:
#   scripts/new-stack.sh <stack> <module-source> [env ...]
#
#   <stack>          folder / fragment name, e.g. "opensearch"
#   <module-source>  Terraform module source, e.g.
#                    "tfr:///terraform-aws-modules/opensearch/aws?version=1.7.0"
#                    or "_modules/<name>" for a local module
#   [env ...]        envs to create shims in (default: dev test prod), or
#                    "global" for a global stack
#
# Existing files are never overwritten. Afterwards: fill in dependencies and
# inputs in _common/<stack>.hcl, then run scripts/lint-shims.sh and
# `terragrunt render --json` in each new stack.
# -----------------------------------------------------------------------------
set -euo pipefail

if [[ $# -lt 2 ]]; then
  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

stack="$1"
source_arg="$2"
shift 2
envs=("$@")
[[ ${#envs[@]} -eq 0 ]] && envs=(dev test prod)

if [[ ! "$stack" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "invalid stack name '$stack' (lowercase letters, digits, dashes)" >&2
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

case "$source_arg" in
  _modules/*)
    [[ -d "$source_arg" ]] || {
      echo "local module $source_arg does not exist" >&2
      exit 2
    }
    # Double slash: Terragrunt copies the whole repo so modules can reference
    # siblings; matches the existing local-module stacks.
    source_hcl="\${get_repo_root()}//${source_arg}"
    ;;
  *) source_hcl="$source_arg" ;;
esac

write_new() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "skip   $path (exists)"
    return
  fi
  mkdir -p "$(dirname "$path")"
  cat >"$path"
  echo "create $path"
}

write_new "_common/${stack}.hcl" <<EOF
# -----------------------------------------------------------------------------
# ${stack} – TODO: one-line description of what this stack manages.
#
# Env-level knobs (<env>/env.hcl): TODO (read with
#   try(local.ctx.env_vars.<knob>, <default>) so env.hcl only lists overrides)
#
# Full Terragrunt fragment included by <env>/<region>/${stack}/terragrunt.hcl.
# Env shims only carry real overrides in \`inputs\`.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("\${get_repo_root()}/_common/_env.hcl").locals
}

terraform {
  source = "${source_hcl}"
}

# Example dependency -- config_path is resolved relative to the stack folder.
# dependency "vpc" {
#   config_path = "../vpc"
#
#   mock_outputs = {
#     vpc_id = "vpc-00000000000000000"
#   }
#   mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
#   mock_outputs_merge_strategy_with_state  = "shallow"
# }

inputs = {
  name = "\${local.ctx.name}-${stack}"
}
EOF

for env in "${envs[@]}"; do
  if [[ "$env" == "global" ]]; then
    dir="global/${stack}"
  else
    region_dirs=("${env}"/*/region.hcl)
    if [[ ! -f "${region_dirs[0]}" ]]; then
      echo "no region.hcl under ${env}/ -- unknown env '${env}'" >&2
      exit 2
    fi
    dir="$(dirname "${region_dirs[0]}")/${stack}"
  fi

  write_new "${dir}/terragrunt.hcl" <<EOF
# Thin shim – source, dependencies and inputs live in _common/${stack}.hcl.
include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path = "\${get_repo_root()}/_common/${stack}.hcl"
}

inputs = {}
EOF
done

echo
echo "Next: edit _common/${stack}.hcl, then run scripts/lint-shims.sh and"
echo "'terragrunt render --json' in each new stack folder."
