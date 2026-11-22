#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Renders every Terragrunt stack to normalised JSON so two snapshots can be
# diffed to prove a refactor is functionally a no-op (issue #45).
#
#   scripts/render-snapshot.sh <out-dir> [stack-dir ...]
#   diff -r <before-dir> <after-dir>
#
# - Uses `render --no-dependency-outputs` (optional-dependency-outputs
#   experiment): dependency outputs are not fetched, so no AWS calls/state
#   reads are needed for dependencies and each stack renders in seconds.
# - Normalisation:
#     * `locals` is dropped: it is an implementation detail and changes by
#       design when locals move from a stack into _common/<stack>.hcl.
#     * Keys are sorted (jq -S).
#     * Render-time timestamps (`-final-YYYYMMDDhhmmss` RDS final snapshot
#       identifiers built from timestamp()) are masked.
# - Without stack-dir arguments, every terragrunt.hcl under dev/ test/ prod/
#   global/ is rendered.
# -----------------------------------------------------------------------------
set -euo pipefail

out="${1:?usage: $0 <out-dir> [stack-dir ...]}"
shift

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
mkdir -p "$out"
out="$(cd "$out" && pwd)"

if [[ $# -gt 0 ]]; then
  stacks=("$@")
else
  mapfile -t stacks < <(find dev test prod global -name terragrunt.hcl -not -path '*/.terragrunt-cache/*' -printf '%h\n' | sort)
fi

export TG_EXPERIMENT=optional-dependency-outputs TG_NO_TIPS=true

render_one() {
  local dir="${1%/}" out="$2" name
  name="$(tr / _ <<<"$dir")"
  if ! (cd "$dir" && terragrunt render --json --no-dependency-outputs --log-level error) >"${out}/${name}.raw" 2>"${out}/${name}.err"; then
    echo "FAIL ${dir} (see ${out}/${name}.err)" >&2
    return 1
  fi
  jq -S 'del(.locals)' "${out}/${name}.raw" |
    sed -E 's/-final-[0-9]{14}/-final-<timestamp>/g' >"${out}/${name}.json"
  rm -f "${out}/${name}.raw" "${out}/${name}.err"
}
export -f render_one

printf '%s\n' "${stacks[@]}" | xargs -P "${PARALLELISM:-8}" -I{} bash -c 'render_one "$@"' _ {} "$out"
echo "rendered ${#stacks[@]} stack(s) into ${out}"
