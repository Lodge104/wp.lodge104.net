locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/route53.hcl")
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  domain = local.project_vars.locals.domain
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "wp_zone" {
  config_path = "../route53-wp"

  mock_outputs = {
    name_servers = [
      "ns-123.awsdns-01.net",
      "ns-456.awsdns-02.org",
      "ns-789.awsdns-03.co.uk",
      "ns-012.awsdns-04.com",
    ]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

inputs = merge(
  local.common.locals,
  {
    name = local.domain
    records = {
      wp_delegation = {
        name    = "wp"
        type    = "NS"
        ttl     = 300
        records = dependency.wp_zone.outputs.name_servers
      }
    }
  }
)
