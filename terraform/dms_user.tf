resource "random_password" "dms_db" {
  length  = 32
  special = false
}

# ── SSM Parameter (read by EC2 instance to create the MySQL user) ─────────────────

resource "aws_ssm_parameter" "dms_db_password" {
  name        = "/lodge104/dms/password"
  type        = "SecureString"
  value       = random_password.dms_db.result
  description = "DMS MySQL user password"
}

# ── Secrets Manager (DMS endpoint connection secret) ─────────────────────────────
# DMS can reference this secret directly when configuring a source endpoint.

resource "aws_secretsmanager_secret" "dms_db" {
  name                    = "${var.environment}/lodge104/dms/db-credentials"
  description             = "DMS source endpoint credentials for lodge104 Aurora cluster"
  recovery_window_in_days = 7

  tags = { Name = "${var.environment}-dms-db-credentials" }
}

resource "aws_secretsmanager_secret_version" "dms_db" {
  secret_id = aws_secretsmanager_secret.dms_db.id

  # Keys match the DMS "Secrets Manager" endpoint format.
  secret_string = jsonencode({
    username = "dms_user"
    password = random_password.dms_db.result
    host     = aws_rds_cluster.wordpress.endpoint
    port     = 3306
    dbname   = var.db_name
    engine   = "mysql"
  })
}

# ── Create the MySQL user via SSM Run Command ─────────────────────────────────────
# Runs scripts/create_dms_user.sh on a live ASG instance. The script reads
# all credentials from SSM — no secrets are passed through this local-exec.

resource "null_resource" "dms_db_user" {
  depends_on = [
    aws_ssm_parameter.dms_db_password,
    aws_rds_cluster_instance.writer,
  ]

  triggers = {
    # Re-run if the password is rotated.
    ssm_param_version = aws_ssm_parameter.dms_db_password.version
  }

  provisioner "local-exec" {
    interpreter = ["python3", "-c"]
    command     = <<-PYTHON
import json, subprocess, sys, time

region    = "${var.aws_region}"
env       = "${var.environment}"
tag_name  = f"{env}-wordpress"
script    = "${path.module}/scripts/create_dms_user.sh"

def run(*args, **kwargs):
    r = subprocess.run(list(args), capture_output=True, text=True, **kwargs)
    if r.returncode != 0 and kwargs.get("check", False):
        print(r.stderr, file=sys.stderr)
        sys.exit(r.returncode)
    return r

print("==> Finding a running WordPress instance...")
r = run("aws", "ec2", "describe-instances",
    "--region", region,
    "--filters",
    f"Name=tag:Name,Values={tag_name}",
    "Name=instance-state-name,Values=running",
    "--query", "Reservations[0].Instances[0].InstanceId",
    "--output", "text")
instance_id = r.stdout.strip()
if not instance_id or instance_id == "None":
    print(f"ERROR: No running instance with tag Name={tag_name}. "
          "Ensure at least one ASG instance is in service.", file=sys.stderr)
    sys.exit(1)
print(f"==> Using instance: {instance_id}")

with open(script) as f:
    commands = [line.rstrip() for line in f.readlines()]

print("==> Sending SSM Run Command...")
r = run("aws", "ssm", "send-command",
    "--region", region,
    "--instance-ids", instance_id,
    "--document-name", "AWS-RunShellScript",
    "--comment", "Create DMS MySQL user",
    "--parameters", json.dumps({"commands": commands}),
    "--query", "Command.CommandId",
    "--output", "text")
command_id = r.stdout.strip()
print(f"==> Command ID: {command_id} — waiting for completion (up to 5 min)...")

status = "Pending"
for _ in range(60):
    time.sleep(5)
    r = run("aws", "ssm", "get-command-invocation",
        "--region", region,
        "--command-id", command_id,
        "--instance-id", instance_id,
        "--query", "Status",
        "--output", "text")
    status = r.stdout.strip()
    if status in ("Success", "Failed", "TimedOut", "Cancelled"):
        break
    print(f"    Status: {status}")

r = run("aws", "ssm", "get-command-invocation",
    "--region", region,
    "--command-id", command_id,
    "--instance-id", instance_id)
inv = json.loads(r.stdout)

stdout = inv.get("StandardOutputContent", "").strip()
stderr = inv.get("StandardErrorContent", "").strip()
if stdout:
    print(stdout)
if stderr:
    print("STDERR:", stderr, file=sys.stderr)

if status != "Success":
    print(f"ERROR: Command finished with status '{status}'", file=sys.stderr)
    sys.exit(1)

print("==> DMS MySQL user created successfully")
    PYTHON
  }
}

# ── Outputs ───────────────────────────────────────────────────────────────────────

output "dms_secret_arn" {
  description = "Secrets Manager ARN for the DMS source endpoint credentials."
  value       = aws_secretsmanager_secret.dms_db.arn
}
