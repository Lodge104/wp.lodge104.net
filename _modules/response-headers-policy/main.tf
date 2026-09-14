terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name = var.name

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = var.cache_control_value
      override = true
    }
  }
}
