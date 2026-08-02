terraform {
  backend "s3" {
    bucket         = "lodge104-terraform-state"
    key            = "lodge104.net/global/route53/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "lodge104-terraform-locks"
    encrypt        = true
  }
}
