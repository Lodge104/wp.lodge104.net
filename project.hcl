locals {
  # Project-level constants shared across every environment and region.
  project_name = "net-lodge104-wp"
  domain       = "lodge104.net"

  # Public hosted zone for the apex domain. Certificates/records for the apex
  # and its direct subdomains (www, store, cdn) are validated/created here
  # rather than in the per-env delegated <env>.wp.<domain> zones.
  parent_zone_id = "Z02518842QX1X2K88785A"
}
