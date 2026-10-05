output "replica_bucket_name" {
  description = "Name of the destination (archive) S3 bucket."
  value       = aws_s3_bucket.replica.bucket
}

output "replica_bucket_arn" {
  description = "ARN of the destination (archive) S3 bucket."
  value       = aws_s3_bucket.replica.arn
}

output "replication_role_arn" {
  description = "ARN of the IAM role used by S3 Replication."
  value       = aws_iam_role.replication.arn
}

output "replication_rule_id" {
  description = "ID of the replication rule created on the source bucket."
  value       = aws_s3_bucket_replication_configuration.this.rule[0].id
}
