# env-promotion

Lambda function that copies the WordPress Aurora MySQL database, EFS
content, and CDN S3 bucket from one environment to another (e.g.
`prod -> test`, `test -> dev`), then automatically rewrites the domain
baked into the copied database, based on a variable passed at invocation
time.

## How it works

1. The Lambda function (`index.handler`) receives an event identifying the
   source and target environments, validates the pair against the
   `allowed_promotions` allow-list, then submits an [AWS Systems Manager Run
   Command](https://docs.aws.amazon.com/systems-manager/latest/userguide/execute-remote-commands.html)
   to the project's bastion host and returns immediately (it does **not**
   wait for the copy to finish -- dumps/restores and large EFS/S3 syncs can
   run well past Lambda's 15-minute limit).
2. The SSM command runs `files/ssm-promote.sh` on the bastion, which:
   - `mysqldump`s the source Aurora cluster and restores it into the target
     cluster (endpoints and master-user credentials are resolved at runtime
     via `rds:DescribeDBClusters` and Secrets Manager -- no static
     credentials are stored anywhere).
   - `rsync`s the source environment's EFS mount (already mounted on the
     bastion under `/mnt/efs/<project>-<env>`, see `_modules/bastion`) into
     the target environment's EFS mount.
   - `aws s3 sync`s the source environment's `<project>-<env>-cdn` bucket
     into the target environment's bucket.
   - `kubectl exec`s into a WordPress pod in the target cluster and runs
     `wp search-replace` to rewrite the source environment's hostname
     (`<source-env>.wp.<domain>`, or the bare `<domain>` for prod) to the
     target environment's hostname, serialization-safe, across every table
     and every multisite blog (see "Domain rewriting" below).
3. Command output streams to the CloudWatch Logs group named in the
   `ssm_command_log_group` output. Poll completion with:

   ```bash
   aws ssm get-command-invocation --command-id <CommandId> \
     --instance-id <bastion_instance_id> --region <region>
   ```

## Invoking

```bash
aws lambda invoke --function-name <function_name> \
  --payload '{"promotion": "prod_to_test"}' response.json
```

or equivalently:

```bash
aws lambda invoke --function-name <function_name> \
  --payload '{"source_env": "test", "target_env": "dev"}' response.json
```

Only pairs present in `allowed_promotions` are accepted; everything else is
rejected before any AWS API call is made.

## Domain rewriting

A byte-for-byte database copy would leave the source environment's
`siteurl`/`home`/per-site domains baked into
`wp_options`/`wp_blogs`/`wp_site`. A naive find/replace on the SQL dump
would corrupt PHP-serialized values once the replacement string has a
different byte length, so instead the final step execs into a live
WordPress pod in the target cluster and runs WP-CLI's serialization-safe
`wp search-replace --all-tables --network`, once for the primary hostname
and once for the `origin.<host>` ALB-facing alias (see
`dev/us-east-1/wordpress/terragrunt.hcl`'s `extraHosts`). Hostnames are
computed from `domain` + the environment name using the same convention as
`_common/wordpress.hcl`: prod uses the bare domain, every other environment
uses `<env>.wp.<domain>`.

If a plugin or custom code also hardcodes additional hostnames (e.g. the
multisite `store.*` site, which can be any domain, not necessarily a literal
subdomain), run an extra `wp search-replace` manually for those after the
promotion completes.

## Prerequisites

- The project bastion (`global/bastion`) must already be deployed, peered to
  every environment's VPC, mounted on every environment's EFS file system,
  and have the extra RDS/Secrets Manager/S3/EKS IAM permissions this module
  depends on (see `_modules/bastion/main.tf` -- `AllowDescribeRdsClusters`,
  `AllowReadRdsManagedSecrets`, `AllowCdnBucketAccess`/`AllowCdnBucketObjects`,
  and `AllowDescribeEksClusters` statements).
- `mysqldump`/`mysql` client, `rsync`, `kubectl`, and the AWS CLI must be
  present on the bastion (already installed by `_modules/bastion`'s user
  data).
- This module itself grants the bastion's IAM role a Kubernetes access entry
  + namespace-scoped `AmazonEKSEditPolicy` on every promotion target
  cluster (`aws_eks_access_entry.bastion` / `aws_eks_access_policy_association.bastion_edit`),
  which is what authorizes the `kubectl exec` step inside the script.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.4 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ssm_document.promote](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_eks_access_entry.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.bastion_edit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_cloudwatch_log_group.ssm_command](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.promote](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [archive_file.lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_eks_clusters.all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_clusters) | data source |
| [aws_iam_policy_document.lambda_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name prefix used by env stacks (for example net-lodge104-wp). | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region where the bastion, RDS clusters, EFS file systems, and S3 buckets live. | `string` | n/a | yes |
| <a name="input_bastion_instance_id"></a> [bastion\_instance\_id](#input\_bastion\_instance\_id) | Instance ID of the SSM-managed bastion host that runs the promotion script. | `string` | n/a | yes |
| <a name="input_bastion_role_arn"></a> [bastion\_role\_arn](#input\_bastion\_role\_arn) | IAM role ARN assumed by the bastion instance (the bastion module's `role_arn` output). Granted an EKS access entry on every promotion target cluster. | `string` | n/a | yes |
| <a name="input_domain"></a> [domain](#input\_domain) | Project base domain (e.g. lodge104.net), used to compute each environment's WordPress hostname for the post-copy search-replace step. | `string` | n/a | yes |
| <a name="input_allowed_promotions"></a> [allowed\_promotions](#input\_allowed\_promotions) | Allow-list of {source, target} environment pairs this function may copy between. | `list(object({ source = string, target = string }))` | n/a | yes |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Helm release name used by the WordPress chart. | `string` | `"wordpress"` | no |
| <a name="input_wordpress_namespace"></a> [wordpress\_namespace](#input\_wordpress\_namespace) | Kubernetes namespace the WordPress Helm release is installed into. | `string` | `"wordpress"` | no |
| <a name="input_ssm_command_timeout_seconds"></a> [ssm\_command\_timeout\_seconds](#input\_ssm\_command\_timeout\_seconds) | Maximum time the SSM command running on the bastion is allowed to run. | `number` | `3600` | no |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | CloudWatch Logs retention. | `number` | `30` | no |
| <a name="input_lambda_timeout_seconds"></a> [lambda\_timeout\_seconds](#input\_lambda\_timeout\_seconds) | Lambda timeout. | `number` | `30` | no |
| <a name="input_lambda_memory_size"></a> [lambda\_memory\_size](#input\_lambda\_memory\_size) | Lambda memory size in MB. | `number` | `128` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Extra tags to apply to resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | Name of the promotion Lambda function. |
| <a name="output_function_arn"></a> [function\_arn](#output\_function\_arn) | ARN of the promotion Lambda function. |
| <a name="output_ssm_document_name"></a> [ssm\_document\_name](#output\_ssm\_document\_name) | Name of the SSM Command document executed on the bastion. |
| <a name="output_ssm_command_log_group"></a> [ssm\_command\_log\_group](#output\_ssm\_command\_log\_group) | CloudWatch Logs group that streams SSM command stdout/stderr. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
