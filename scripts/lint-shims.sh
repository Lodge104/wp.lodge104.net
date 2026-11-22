#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Lints that converted env/global stacks are thin shims (issue #45):
#   - include "root" + include "common" (pointing at _common/<something>.hcl)
#   - no terraform { source }, no dependency blocks, no locals
#   - at most MAX_LINES lines (default 15)
#
# A stack counts as "converted" once it has an `include "common"` block, so this
# can run in CI during the phased rollout; unconverted stacks are reported as
# "todo" (pass --strict to fail on them, for the end state).
#
# Usage: scripts/lint-shims.sh [--strict]
# -----------------------------------------------------------------------------
set -euo pipefail

strict=false
[[ "${1:-}" == "--strict" ]] && strict=true
max_lines="${MAX_LINES:-15}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

fail=0 ok=0 todo=0
while IFS= read -r f; do
  if ! grep -q '^include "common"' "$f"; then
    todo=$((todo + 1))
    if $strict; then
      echo "FAIL $f: not converted to a shim (no include \"common\")"
      fail=1
    fi
    continue
  fi

  errs=()
  lines="$(wc -l <"$f")"
  ((lines > max_lines)) && errs+=("${lines} lines > ${max_lines}")
  grep -q '^include "root"' "$f" || errs+=("missing include \"root\"")
  grep -qE '^\s*path\s*=\s*"\$\{get_repo_root\(\)\}/_common/[^"]+\.hcl"' "$f" || errs+=("include \"common\" must point at _common/*.hcl")
  grep -qE '^\s*dependency\s+"' "$f" && errs+=("contains a dependency block")
  grep -qE '^\s*dependencies\s*\{' "$f" && errs+=("contains a dependencies block")
  grep -qE '^\s*terraform\s*\{' "$f" && errs+=("contains a terraform block")
  grep -qE '^\s*locals\s*\{' "$f" && errs+=("contains a locals block")

  if ((${#errs[@]})); then
    for e in "${errs[@]}"; do echo "FAIL $f: $e"; done
    fail=1
  else
    ok=$((ok + 1))
  fi
done < <(find dev test prod global -name terragrunt.hcl -not -path '*/.terragrunt-cache/*' | sort)

echo "shims ok: ${ok}, not yet converted: ${todo}"
exit "$fail"
