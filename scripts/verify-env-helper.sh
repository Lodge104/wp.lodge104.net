#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Verifies that _common/_env.hcl resolves the correct env / region / project
# context both when read directly from a stack terragrunt.hcl and when read
# from an included _common/<stack>.hcl fragment, for every env and for global/.
#
# Creates throwaway probe stacks (no Terraform is run, only `terragrunt
# render`), checks the rendered values and removes the probes again.
#
# Usage: scripts/verify-env-helper.sh
# -----------------------------------------------------------------------------
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

probe="zz-env-helper-probe"
common="_common/${probe}.hcl"
dirs=()

cleanup() {
  rm -f "$common"
  for d in "${dirs[@]}"; do rm -rf "$d"; done
}
trap cleanup EXIT

# Included fragment: reads the helper from inside an included file.
cat >"$common" <<'EOF'
locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
}
inputs = {
  via_include = {
    env        = local.ctx.env
    region     = local.ctx.region
    project    = local.ctx.project
    name       = local.ctx.name
    is_prod    = local.ctx.is_prod
    env_domain = local.ctx.env_domain
    stack_name = local.ctx.stack_name
  }
}
EOF

project="$(sed -n 's/^ *project_name *= *"\(.*\)".*/\1/p' project.hcl)"
domain="$(sed -n 's/^ *domain *= *"\(.*\)".*/\1/p' project.hcl)"

# <stack dir>|<expected env>|<expected region>|<expected is_prod>|<expected env_domain>
cases=()
for env_dir in */env.hcl; do
  env_dir="${env_dir%/env.hcl}"
  env="$(sed -n 's/^ *env *= *"\(.*\)".*/\1/p' "${env_dir}/env.hcl" | head -1)"
  for region_file in "${env_dir}"/*/region.hcl; do
    region_dir="$(dirname "$region_file")"
    region="$(sed -n 's/^ *aws_region *= *"\(.*\)".*/\1/p' "$region_file")"
    is_prod=false
    [[ "$env" == "prod" ]] && is_prod=true
    cases+=("${region_dir}/${probe}|${env}|${region}|${is_prod}|${env}.wp.${domain}")
  done
done
global_region="$(sed -n 's/^ *aws_region *= *"\(.*\)".*/\1/p' global/region.hcl)"
cases+=("global/${probe}|global|${global_region}|false|null")

fail=0
for c in "${cases[@]}"; do
  IFS='|' read -r dir exp_env exp_region exp_prod exp_domain <<<"$c"
  dirs+=("$dir")
  mkdir -p "$dir"
  cat >"${dir}/terragrunt.hcl" <<EOF
include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path = "\${get_repo_root()}/${common}"
}

locals {
  ctx = read_terragrunt_config("\${get_repo_root()}/_common/_env.hcl").locals
}

inputs = {
  direct = {
    env        = local.ctx.env
    region     = local.ctx.region
    project    = local.ctx.project
    name       = local.ctx.name
    is_prod    = local.ctx.is_prod
    env_domain = local.ctx.env_domain
    stack_name = local.ctx.stack_name
  }
}
EOF

  json="$(cd "$dir" && terragrunt render --json --log-level error)"

  for scope in direct via_include; do
    got="$(jq -c --arg s "$scope" '.inputs[$s] | [.env, .region, .project, .name, .is_prod, .env_domain, .stack_name]' <<<"$json")"
    if [[ "$exp_domain" == "null" ]]; then dom='null'; else dom="\"${exp_domain}\""; fi
    want="[\"${exp_env}\",\"${exp_region}\",\"${project}\",\"${project}-${exp_env}\",${exp_prod},${dom},\"${probe}\"]"
    if [[ "$got" == "$want" ]]; then
      echo "ok   ${dir} (${scope})"
    else
      echo "FAIL ${dir} (${scope}): got ${got}, want ${want}"
      fail=1
    fi
  done

  # State key must still be derived from the stack path.
  key="$(jq -r '.remote_state.config.key' <<<"$json")"
  if [[ "$key" == "${dir}/terraform.tfstate" ]]; then
    echo "ok   ${dir} (remote_state key)"
  else
    echo "FAIL ${dir} (remote_state key): got ${key}"
    fail=1
  fi
done

cleanup
trap - EXIT
exit "$fail"
