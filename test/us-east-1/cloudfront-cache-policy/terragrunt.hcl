locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  project = local.project_vars.locals.project_name
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${get_repo_root()}/_modules/response-headers-policy"
}

# Forces a long-lived, immutable Cache-Control on the WordPress distribution's
# static-asset behaviors (themes/plugins/wp-includes/uploads) served via the
# ALB origin, regardless of what the origin sends.
inputs = {
  name = "${local.project}-${local.env}-static-assets-cache"
}
