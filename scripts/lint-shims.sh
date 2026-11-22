#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Lints that every env/global stack terragrunt.hcl is a thin shim (#45):
#   - include "root" (find_in_parent_folders("root.hcl")) + include "common"
#     pointing at an existing _common/<name>.hcl fragment
#   - no terraform / dependency / dependencies / generate / locals blocks
#   - no direct env/region/project lookups (read_terragrunt_config,
#     find_in_parent_folders("env.hcl") etc.) -- use _common/_env.hcl
#   - at most MAX_LINES lines (default 15)
#
# Every stack must be a shim (all phases of #45 are done). Pass --allow-todo to
# only report, not fail on, stacks without an include "common" (e.g. while
# migrating a new stack by hand).
#
# Usage: scripts/lint-shims.sh [--allow-todo]
# -----------------------------------------------------------------------------
set -euo pipefail

allow_todo=false
case "${1:-}" in
  --allow-todo) allow_todo=true ;;
  --strict | "") ;; # --strict kept as a no-op alias for older callers
  *)
    echo "usage: $0 [--allow-todo]" >&2
    exit 2
    ;;
esac
max_lines="${MAX_LINES:-15}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

fail=0 ok=0 todo=0
while IFS= read -r f; do
  if ! grep -q '^include "common"' "$f"; then
    todo=$((todo + 1))
    echo "$($allow_todo && echo TODO || echo FAIL) $f: not a shim (no include \"common\")"
    $allow_todo || fail=1
    continue
  fi

  errs=()
  lines="$(wc -l <"$f")"
  ((lines > max_lines)) && errs+=("${lines} lines > ${max_lines}")

  grep -qE '^\s*path\s*=\s*find_in_parent_folders\("root\.hcl"\)' "$f" ||
    errs+=('include "root" must use find_in_parent_folders("root.hcl")')

  common="$(sed -nE 's#^\s*path\s*=\s*"\$\{get_repo_root\(\)\}/(_common/[^"]+\.hcl)"#\1#p' "$f" | head -1)"
  if [[ -z "$common" ]]; then
    errs+=('include "common" must point at "${get_repo_root()}/_common/<name>.hcl"')
  elif [[ ! -f "$common" ]]; then
    errs+=("include \"common\" target ${common} does not exist")
  fi

  for block in terraform dependency dependencies generate locals remote_state; do
    grep -qE "^\s*${block}(\s+\"[^\"]*\")?\s*\{" "$f" && errs+=("contains a ${block} block (belongs in _common)")
  done
  grep -qE 'read_terragrunt_config|find_in_parent_folders\("(env|region|project)\.hcl"\)' "$f" &&
    errs+=("reads env/region/project config directly (use _common/_env.hcl)")

  if ((${#errs[@]})); then
    for e in "${errs[@]}"; do echo "FAIL $f: $e"; done
    fail=1
  else
    ok=$((ok + 1))
  fi
done < <(find dev test prod global -name terragrunt.hcl -not -path '*/.terragrunt-cache/*' | sort)

echo "shims ok: ${ok}, not converted: ${todo}"
exit "$fail"
