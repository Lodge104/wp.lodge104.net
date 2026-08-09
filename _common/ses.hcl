# Common SES SMTP user defaults – override in each env's terragrunt.hcl as needed.
locals {
  # The SES domain identity (and its DKIM/SPF/DMARC DNS records) for the
  # project's domain is assumed to already exist and be verified in this
  # account; this module only provisions IAM SMTP credentials scoped to
  # send through it.
  name = "ses-smtp"
}
