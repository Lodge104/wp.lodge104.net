# Thin shim – source, dependencies and inputs live in _common/rds.hcl.
include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path = "${get_repo_root()}/_common/rds.hcl"
}

inputs = {}
