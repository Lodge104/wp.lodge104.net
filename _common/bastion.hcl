locals {
  environment_names = ["dev", "test", "prod"]

  # Prefer running the bastion in prod when it exists, then test, then dev.
  bastion_home_env_preference = ["prod", "test", "dev"]

  instance_type = "t3.small"

  # Keep this tiny because the host is SSM-only and for operational access.
  root_volume_size = 20

  transfer_bucket_name = "lodge104-transfer-1"

  tags = {
    Component = "bastion"
    ManagedBy = "terraform"
  }
}
