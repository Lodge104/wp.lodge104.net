# -----------------------------------------------------------------------------
# ses – IAM SMTP credentials for sending through SES.
#
# The SES domain identity (and its DKIM/SPF/DMARC DNS records) for the
# project's domain is assumed to already exist and be verified in this
# account; this module only provisions IAM SMTP credentials scoped to send
# through it.
#
# Full Terragrunt fragment included by <env>/<region>/ses/terragrunt.hcl. Env
# shims only carry real overrides in `inputs`.
# -----------------------------------------------------------------------------

locals {
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
}

terraform {
  source = "${get_repo_root()}//_modules/ses-smtp-user"
}

inputs = {
  name                   = "ses-smtp-${local.ctx.env}"
  domain                 = local.ctx.domain
  region                 = local.ctx.region
  secret_name            = "${local.ctx.name}-ses-credentials"
  configuration_set_name = "lodge104-ses"
}
