# efs

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.32 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.32 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_efs_file_system.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |
| [aws_eks_pod_identity_association.efs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_iam_role.efs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.efs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_security_group.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [kubernetes_storage_class_v1.efs_sc](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class_v1) | resource |
| [terraform_data.efs_csi_controller_restart](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_policy_document.efs_csi_pod_identity_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_eks_cluster_name"></a> [eks\_cluster\_name](#input\_eks\_cluster\_name) | EKS cluster name. Used to look up cluster endpoint/CA for the Kubernetes provider. | `string` | n/a | yes |
| <a name="input_eks_node_security_group_id"></a> [eks\_node\_security\_group\_id](#input\_eks\_node\_security\_group\_id) | Security group ID attached to EKS managed node groups. Granted NFS ingress to EFS. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name prefix used for the EFS file system, security group, and StorageClass. | `string` | n/a | yes |
| <a name="input_performance_mode"></a> [performance\_mode](#input\_performance\_mode) | EFS performance mode. Allowed values: generalPurpose, maxIO. | `string` | `"generalPurpose"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region where the EKS cluster is deployed. Passed as --region to aws eks get-token. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of private subnet IDs in which to create EFS mount targets (one per AZ). | `list(string)` | n/a | yes |
| <a name="input_throughput_mode"></a> [throughput\_mode](#input\_throughput\_mode) | EFS throughput mode. Allowed values: bursting, provisioned, elastic. | `string` | `"elastic"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where EFS mount targets will be created. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_file_system_arn"></a> [file\_system\_arn](#output\_file\_system\_arn) | EFS file system ARN. |
| <a name="output_file_system_id"></a> [file\_system\_id](#output\_file\_system\_id) | EFS file system ID. |
| <a name="output_storage_class_name"></a> [storage\_class\_name](#output\_storage\_class\_name) | Kubernetes StorageClass name created for EFS (efs-sc). |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
