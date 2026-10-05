# s3-replication

One-way S3 Cross-Region Replication from an existing bucket to a dedicated
archive bucket in another Region, storing replicas directly in
`DEEP_ARCHIVE`.

## Behavior

- Only objects created or updated **after** this module is applied are
  replicated. Objects already in the source bucket at apply time are **not**
  backfilled automatically (S3 live replication never covers pre-existing
  objects) -- see [Backfilling existing objects](#backfilling-existing-objects)
  below.
- Replication is one-way and non-destructive on the destination:
  - `delete_marker_replication` is `Disabled`, and the replication IAM role
    is not granted `s3:ReplicateDelete`. Deleting an object (or a specific
    version) in the source bucket never deletes or touches its replica in
    the archive bucket.
  - The archive bucket is otherwise private, has no lifecycle rules, and
    nothing else writes to it, so replicas are only ever added, never
    removed, by this module's design.
- Replicas land straight in `DEEP_ARCHIVE` storage class in the destination
  bucket regardless of the source object's storage class.
- Requires versioning on both the source and destination buckets. This
  module enables versioning on the destination bucket it creates; the source
  bucket must already be versioned (it is, in this project's CDN module).

## Backfilling existing objects

To copy objects that already existed in the source bucket before this
replication rule was created, run a one-time [S3 Batch Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-batch-replication-batch.html)
job after `terragrunt apply` succeeds. Batch Replication is not a Terraform
resource -- it's a one-time job best run via the console or CLI, which also
makes it easy to re-run or filter by prefix if it fails partway through.

1. Open the source bucket in the S3 console → **Management** →
   **Replication rules** → select the rule created by this module → open
   its details. There's an entry point there to **Create replication job
   for existing objects** which generates the manifest and permissions for
   you.
2. Alternatively, via the CLI, create a Batch Operations job with
   `--operation '{"S3ReplicateObject": {}}'` using a manifest generated from
   the replication configuration (`ReplicationConfiguration` manifest
   generator). See [Create a Batch Replication job for existing replication
   rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-batch-replication-existing-config.html).
3. The job needs its own IAM role (distinct from the live-replication role)
   with S3 Batch Operations permissions -- the console flow creates this for
   you; for the CLI, follow [Configuring an IAM role for S3 Batch
   Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-replication-role-manual.html).
4. Batch Replication is a one-time, on-demand job (billed per object/GB
   processed) -- it does not need to be re-run unless new pre-existing
   objects are discovered or a prior attempt partially failed.

## Inputs

| Name | Description |
| --- | --- |
| `source_bucket_name` / `source_bucket_arn` | The existing bucket to replicate from. Must already have versioning enabled. |
| `destination_bucket_name` | Name for the new archive bucket this module creates. |
| `destination_region` | Region for the archive bucket (e.g. `us-west-2`). |
| `replication_role_name` | Name for the IAM role S3 assumes to replicate objects. |
| `replication_rule_id` | Identifier for the replication rule. |
| `tags` | Tags applied to the archive bucket and IAM role. |
