# ses-smtp-user

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_access_key.smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_user.smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy.send_email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.send_email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_domain"></a> [domain](#input\_domain) | Verified SES domain identity to scope the IAM user's sending permission to (e.g. lodge104.net). | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name for the IAM user used as the SES SMTP sender. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the SES domain identity was verified in. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_smtp_password"></a> [smtp\_password](#output\_smtp\_password) | SES SMTP password, derived from the IAM secret access key using AWS's SigV4-based algorithm. |
| <a name="output_smtp_username"></a> [smtp\_username](#output\_smtp\_username) | SES SMTP username (IAM access key ID). |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
