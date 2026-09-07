locals {
  # Existing public hosted zone for lodge104.net. This cutover manages only
  # the root, store, and media CDN aliases; delegated zones remain separate.
  create_zone = false
  zone_id     = "Z02518842QX1X2K88785A"
}