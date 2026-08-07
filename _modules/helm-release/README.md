# helm-release

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.16 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.32 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.9 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.16 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.32 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.6 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.9 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_secretsmanager_secret.wordpress_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.wordpress_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [helm_release.this](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.rds_credentials](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.ses_smtp_credentials](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.wordpress_admin](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [random_password.wordpress_admin](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.wordpress_admin_username](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_sleep.wait_for_ingress](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_secretsmanager_secret_version.rds_master_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [aws_secretsmanager_secret_version.wordpress_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [kubernetes_ingress_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/ingress_v1) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_atomic"></a> [atomic](#input\_atomic) | Roll back the release automatically on failure. | `bool` | `false` | no |
| <a name="input_chart"></a> [chart](#input\_chart) | Helm chart name. | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Helm chart version to pin. | `string` | n/a | yes |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Create the Kubernetes namespace if it does not already exist. | `bool` | `true` | no |
| <a name="input_create_wordpress_admin_credentials"></a> [create\_wordpress\_admin\_credentials](#input\_create\_wordpress\_admin\_credentials) | Generate an initial WordPress admin user (random username and password), store the credentials in an AWS Secrets Manager secret, and sync the password into a Kubernetes Secret referenced via the chart's `existingSecret` value. | `bool` | `false` | no |
| <a name="input_expose_ingress_hostname"></a> [expose\_ingress\_hostname](#input\_expose\_ingress\_hostname) | Read back the hostname of a Kubernetes Ingress created by this release (e.g. an ALB DNS name) once it's provisioned, exposed via the `ingress_hostname` output. | `bool` | `false` | no |
| <a name="input_ingress_name"></a> [ingress\_name](#input\_ingress\_name) | Name of the Kubernetes Ingress resource to read back when `expose_ingress_hostname` is true. Required when `expose_ingress_hostname` is set. | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for the release. | `string` | `"default"` | no |
| <a name="input_rds_master_user_secret_arn"></a> [rds\_master\_user\_secret\_arn](#input\_rds\_master\_user\_secret\_arn) | ARN of the AWS Secrets Manager secret holding the RDS master user credentials (the rds-aurora module's `cluster_master_user_secret[0].secret_arn` output, populated when `manage_master_user_password = true`). When set, a Kubernetes Secret named `rds_secret_name` is created in `namespace` with the password under key `rds_secret_key`, removing the need to create it manually. | `string` | `null` | no |
| <a name="input_rds_secret_key"></a> [rds\_secret\_key](#input\_rds\_secret\_key) | Key within the created Kubernetes Secret's data map that holds the password. | `string` | `"mariadb-password"` | no |
| <a name="input_rds_secret_name"></a> [rds\_secret\_name](#input\_rds\_secret\_name) | Name of the Kubernetes Secret to create from the RDS master user secret. Required when `rds_master_user_secret_arn` is set. | `string` | `null` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Helm release name. | `string` | n/a | yes |
| <a name="input_repository"></a> [repository](#input\_repository) | Helm chart OCI repository URL (e.g. oci://registry-1.docker.io/bitnamicharts). | `string` | n/a | yes |
| <a name="input_ses_secret_key"></a> [ses\_secret\_key](#input\_ses\_secret\_key) | Key within the created Kubernetes Secret's data map that holds the SES SMTP password. Must be "smtp-password" for the Bitnami WordPress chart's smtpExistingSecret to find it, unless the chart changes this requirement. | `string` | `"smtp-password"` | no |
| <a name="input_ses_secret_name"></a> [ses\_secret\_name](#input\_ses\_secret\_name) | Name of the Kubernetes Secret to create from the SES SMTP password. Required when `ses_smtp_password` is set. | `string` | `null` | no |
| <a name="input_ses_smtp_password"></a> [ses\_smtp\_password](#input\_ses\_smtp\_password) | SES SMTP password (e.g. the ses-smtp-user module's `smtp_password` output) to store in a Kubernetes Secret for the chart's `smtpExistingSecret` to reference. When set, a Kubernetes Secret named `ses_secret_name` is created in `namespace` with the password under key `ses_secret_key`. | `string` | `null` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Time in seconds to wait for Helm operations to complete. | `number` | `600` | no |
| <a name="input_values"></a> [values](#input\_values) | List of raw YAML values strings (equivalent to -f values.yaml). Rendered in order; later entries override earlier ones. | `list(string)` | `[]` | no |
| <a name="input_wait"></a> [wait](#input\_wait) | Wait until all Kubernetes resources are in a ready state. | `bool` | `true` | no |
| <a name="input_wordpress_admin_password_length"></a> [wordpress\_admin\_password\_length](#input\_wordpress\_admin\_password\_length) | Length of the randomly generated initial WordPress admin password. | `number` | `24` | no |
| <a name="input_wordpress_admin_secret_name"></a> [wordpress\_admin\_secret\_name](#input\_wordpress\_admin\_secret\_name) | Name for the AWS Secrets Manager secret and matching Kubernetes Secret holding the initial WordPress admin credentials. Must be a valid Kubernetes DNS subdomain because it is used unchanged for both resources. Required when `create_wordpress_admin_credentials` is true. | `string` | `null` | no |
| <a name="input_wordpress_admin_secret_recovery_window_in_days"></a> [wordpress\_admin\_secret\_recovery\_window\_in\_days](#input\_wordpress\_admin\_secret\_recovery\_window\_in\_days) | Number of days AWS Secrets Manager waits before permanently deleting the WordPress admin credentials secret after destruction. Set to 0 to delete immediately (useful for ephemeral/dev environments). | `number` | `0` | no |
| <a name="input_wordpress_admin_username_prefix"></a> [wordpress\_admin\_username\_prefix](#input\_wordpress\_admin\_username\_prefix) | Prefix used when generating the random initial WordPress admin username (a random alphanumeric suffix is appended). | `string` | `"admin"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ingress_hostname"></a> [ingress\_hostname](#output\_ingress\_hostname) | Hostname of the load balancer backing the release's Ingress (e.g. an ALB DNS name), when `expose_ingress_hostname` is true. Null otherwise, or if the load balancer isn't provisioned yet. |
| <a name="output_release_name"></a> [release\_name](#output\_release\_name) | Helm release name. |
| <a name="output_release_namespace"></a> [release\_namespace](#output\_release\_namespace) | Kubernetes namespace of the Helm release. |
| <a name="output_release_status"></a> [release\_status](#output\_release\_status) | Current status of the Helm release. |
| <a name="output_wordpress_admin_secret_arn"></a> [wordpress\_admin\_secret\_arn](#output\_wordpress\_admin\_secret\_arn) | ARN of the AWS Secrets Manager secret holding the initial WordPress admin credentials (username and password), when `create_wordpress_admin_credentials` is true. Null otherwise. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
