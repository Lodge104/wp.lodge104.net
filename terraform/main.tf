# ============================================================
# Lightsail — Main WordPress Multisite Instance
# lodge104-main.6.9.1 (medium_3_0: 2 vCPU, 4 GB RAM, 80 GB SSD)
# ============================================================

# -- Import existing resources --------------------------------
# These resources have been imported into state:
#   terraform import aws_lightsail_certificate.main   lodge104-net
#   terraform import aws_lightsail_instance.main      lodge104-main.6.9.1
#   terraform import aws_lightsail_distribution.main  lodge104-main-cdn
#
# Note: aws_lightsail_static_ip and aws_lightsail_static_ip_attachment do not
# support import (provider limitation). The static IP lodge104-main-ip /
# 44.209.203.111 is managed outside Terraform.
#
# Note: aws_lightsail_instance_public_ports does not support import; the first
# terraform apply will write the correct rules (no destructive change).
# ------------------------------------------------------------

# -- Certificate (used by the CDN distribution) --------------

resource "aws_lightsail_certificate" "main" {
  name        = "lodge104-net"
  domain_name = "lodge104.net"

  subject_alternative_names = [
    "www.lodge104.net",
    "store.lodge104.net",
    "www.store.lodge104.net",
    "store-test.lodge104.net",
    "www.store-test.lodge104.net",
  ]
}

# -- Instance ------------------------------------------------

resource "aws_lightsail_instance" "main" {
  name              = "lodge104-main.6.9.1"
  availability_zone = "us-east-1a"
  blueprint_id      = "wordpress_multisite"
  bundle_id         = "medium_3_0"
  key_pair_name     = "lodge104-home"
  ip_address_type   = "dualstack"

  add_on {
    type          = "AutoSnapshot"
    snapshot_time = "04:00"
    status        = "Enabled"
  }
}

# -- Firewall (open ports) -----------------------------------

resource "aws_lightsail_instance_public_ports" "main" {
  instance_name = aws_lightsail_instance.main.name

  port_info {
    from_port  = 22
    to_port    = 22
    protocol   = "tcp"
    cidrs      = ["0.0.0.0/0"]
    ipv6_cidrs = ["::/0"]
  }

  port_info {
    from_port  = 80
    to_port    = 80
    protocol   = "tcp"
    cidrs      = ["0.0.0.0/0"]
    ipv6_cidrs = ["::/0"]
  }

  port_info {
    from_port  = 443
    to_port    = 443
    protocol   = "tcp"
    cidrs      = ["0.0.0.0/0"]
    ipv6_cidrs = ["::/0"]
  }

  port_info {
    from_port  = 6379
    to_port    = 6379
    protocol   = "tcp"
    cidrs      = ["0.0.0.0/0"]
    ipv6_cidrs = ["::/0"]
  }
}

# -- Static IP -----------------------------------------------
# lodge104-main-ip (44.209.203.111) is managed outside Terraform.
# aws_lightsail_static_ip does not support import in the AWS provider.

# -- CDN Distribution ----------------------------------------
# Origin: lodge104-main.6.9.1 (HTTP only, port 80)
# Domains: lodge104.net, www.lodge104.net, store.lodge104.net,
#           www.store.lodge104.net, store-test.lodge104.net,
#           www.store-test.lodge104.net

resource "aws_lightsail_distribution" "main" {
  name            = "lodge104-main-cdn"
  bundle_id       = "small_1_0"
  ip_address_type = "dualstack"

  certificate_name = aws_lightsail_certificate.main.name

  origin {
    name            = aws_lightsail_instance.main.name
    region_name     = "us-east-1"
    protocol_policy = "http-only"
  }

  default_cache_behavior {
    behavior = "dont-cache"
  }

  cache_behavior_settings {
    default_ttl          = 86400
    minimum_ttl          = 0
    maximum_ttl          = 31536000
    allowed_http_methods = "GET,HEAD,OPTIONS"
    cached_http_methods  = "GET,HEAD"

    forwarded_cookies {
      option = "none"
    }

    forwarded_headers {
      option             = "allow-list"
      headers_allow_list = ["Host"]
    }

    forwarded_query_strings {
      option = true
    }
  }

  cache_behavior {
    path     = "wp-includes/*"
    behavior = "cache"
  }

  cache_behavior {
    path     = "wp-content/*"
    behavior = "cache"
  }

  is_enabled = true
}
