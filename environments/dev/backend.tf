terraform {
  backend "s3" {
    bucket       = "lodge104-terraform-state-dev"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
