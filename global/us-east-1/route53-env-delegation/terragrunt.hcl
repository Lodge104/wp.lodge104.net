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

dependency "prod_zone" {
  config_path = "${get_repo_root()}/prod/us-east-1/route53"

  mock_outputs = {
    name_servers = [
      "ns-111.awsdns-01.net",
      "ns-222.awsdns-02.org",
      "ns-333.awsdns-03.co.uk",
      "ns-444.awsdns-04.com",
    ]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

dependency "dev_zone" {
  config_path = "${get_repo_root()}/dev/us-east-1/route53"

  mock_outputs = {
    name_servers = [
      "ns-555.awsdns-01.net",
      "ns-666.awsdns-02.org",
      "ns-777.awsdns-03.co.uk",
      "ns-888.awsdns-04.com",
    ]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

dependency "test_zone" {
  config_path = "${get_repo_root()}/test/us-east-1/route53"

  mock_outputs = {
    name_servers = [
      "ns-999.awsdns-01.net",
      "ns-000.awsdns-02.org",
      "ns-121.awsdns-03.co.uk",
      "ns-131.awsdns-04.com",
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
    name = "wp.${local.domain}"
    records = {
      prod_delegation = {
        name    = "prod"
        type    = "NS"
        ttl     = 300
        records = dependency.prod_zone.outputs.name_servers
      }
      dev_delegation = {
        name    = "dev"
        type    = "NS"
        ttl     = 300
        records = dependency.dev_zone.outputs.name_servers
      }
      test_delegation = {
        name    = "test"
        type    = "NS"
        ttl     = 300
        records = dependency.test_zone.outputs.name_servers
      }
    }
  }
)
