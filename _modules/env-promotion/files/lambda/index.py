"""
Triggers an SSM Run Command on the project bastion host that copies the
WordPress Aurora MySQL database, EFS content, and CDN S3 bucket from one
environment to another (e.g. prod -> test, test -> dev), then runs a
serialization-safe `wp search-replace` in the target cluster to fix up the
domain baked into the copied database.

This function only *submits* the SSM command and returns -- the copy itself
(database dump/restore, EFS rsync, S3 sync) can take anywhere from minutes
to over an hour depending on data size, which is well beyond Lambda's
15-minute hard limit. Track progress with:

  aws ssm get-command-invocation --command-id <CommandId> \
      --instance-id <bastion_instance_id> --region <region>

or by tailing the CloudWatch Logs group returned as `log_group` (also
configured via the CLOUDWATCH_LOG_GROUP_NAME environment variable).

Event shape -- either form is accepted:
  {"promotion": "prod_to_test"}
  {"source_env": "prod", "target_env": "test"}

The source/target pair must appear in the ALLOWED_PROMOTIONS environment
variable (JSON list of {"source": ..., "target": ...} objects), which is
set from the `allowed_promotions` Terraform variable.
"""
import json
import os

import boto3

ssm = boto3.client("ssm")

BASTION_INSTANCE_ID = os.environ["BASTION_INSTANCE_ID"]
SSM_DOCUMENT_NAME = os.environ["SSM_DOCUMENT_NAME"]
PROJECT_NAME = os.environ["PROJECT_NAME"]
REGION = os.environ["REGION"]
DOMAIN = os.environ["DOMAIN"]
RELEASE_NAME = os.environ["RELEASE_NAME"]
WORDPRESS_NAMESPACE = os.environ["WORDPRESS_NAMESPACE"]
ALLOWED_PROMOTIONS = json.loads(os.environ["ALLOWED_PROMOTIONS"])
SSM_COMMAND_TIMEOUT_SECONDS = int(os.environ["SSM_COMMAND_TIMEOUT_SECONDS"])
CLOUDWATCH_LOG_GROUP_NAME = os.environ["CLOUDWATCH_LOG_GROUP_NAME"]


def _parse_event(event):
    promotion = event.get("promotion")
    if promotion:
        try:
            source_env, target_env = promotion.split("_to_", 1)
        except ValueError as exc:
            raise ValueError(
                "`promotion` must be in the form '<source_env>_to_<target_env>', "
                "e.g. 'prod_to_test'."
            ) from exc
        return source_env, target_env

    source_env = event.get("source_env")
    target_env = event.get("target_env")
    if not source_env or not target_env:
        raise ValueError(
            "Event must set either `promotion` (e.g. 'prod_to_test') or both "
            "`source_env` and `target_env`."
        )
    return source_env, target_env


def _validate(source_env, target_env):
    for promotion in ALLOWED_PROMOTIONS:
        if promotion["source"] == source_env and promotion["target"] == target_env:
            return
    allowed = ", ".join(f'{p["source"]}->{p["target"]}' for p in ALLOWED_PROMOTIONS)
    raise ValueError(
        f"Promotion '{source_env}->{target_env}' is not allowed. "
        f"Allowed promotions: {allowed}"
    )


def handler(event, context):
    source_env, target_env = _parse_event(event)
    _validate(source_env, target_env)

    print(f"Submitting promotion {source_env} -> {target_env} via bastion {BASTION_INSTANCE_ID}")

    response = ssm.send_command(
        InstanceIds=[BASTION_INSTANCE_ID],
        DocumentName=SSM_DOCUMENT_NAME,
        Comment=f"{PROJECT_NAME} env promotion {source_env}->{target_env}",
        TimeoutSeconds=SSM_COMMAND_TIMEOUT_SECONDS,
        Parameters={
            "ProjectName": [PROJECT_NAME],
            "SourceEnv": [source_env],
            "TargetEnv": [target_env],
            "Region": [REGION],
            "Domain": [DOMAIN],
            "ReleaseName": [RELEASE_NAME],
            "Namespace": [WORDPRESS_NAMESPACE],
        },
        CloudWatchOutputConfig={
            "CloudWatchLogGroupName": CLOUDWATCH_LOG_GROUP_NAME,
            "CloudWatchOutputEnabled": True,
        },
    )

    command_id = response["Command"]["CommandId"]
    print(f"Submitted SSM command {command_id}")

    return {
        "command_id": command_id,
        "bastion_instance_id": BASTION_INSTANCE_ID,
        "source_env": source_env,
        "target_env": target_env,
        "status_check_cli": (
            f"aws ssm get-command-invocation --command-id {command_id} "
            f"--instance-id {BASTION_INSTANCE_ID} --region {REGION}"
        ),
        "log_group": CLOUDWATCH_LOG_GROUP_NAME,
    }
