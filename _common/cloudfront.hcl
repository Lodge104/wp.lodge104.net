# Common CloudFront defaults – override in each env's terragrunt.hcl as needed.
#
# Caching strategy tuned for WordPress/WooCommerce (bitnami/wordpress served
# behind the ALB origin, no server-side full-page cache plugin installed):
#   - Default behavior handles front-end HTML/REST/comment-post traffic. It
#     must allow write methods (WordPress uses POST for comments,
#     admin-ajax fallbacks and the REST API) and must NOT share cached pages
#     between anonymous and logged-in/commenting visitors, so it forwards
#     the auth/state cookies WordPress/WooCommerce relies on (wildcards
#     match per-install hashed cookie names) and forwards query strings
#     (preview, search, pagination links all depend on them). default_ttl is
#     set to a short micro-cache window for anonymous navigation latency
#     improvements while still allowing origin cache headers to take
#     precedence.
#   - wp-admin/wp-login/xmlrpc are always dynamic and session-specific, so
#     they're fully excluded from caching and forward everything to origin.
#   - Static assets (uploads, core/theme/plugin files) are safe to cache
#     aggressively since they're content-addressed by path/filename.
locals {
  price_class = "PriceClass_100" # US, Canada, Europe

  is_ipv6_enabled     = true
  http_version        = "http2and3"
  wait_for_deployment = false

  # Default cache behaviour – front-end pages, comments, REST API.
  default_cache_behavior = {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    min_ttl     = 0
    default_ttl = 60
    max_ttl     = 86400

    use_forwarded_values = true
    query_string         = true
    # Forwarding Host lets WordPress Multisite (subdomain install) resolve
    # which network site to serve. Without this, CloudFront overrides the
    # Host header sent to the ALB origin with the origin's own domain name
    # for every request, so every site would resolve to the primary blog.
    # This also folds Host into the cache key (legacy forwarded_values
    # behavior), which is the desired trade-off here: it keeps each
    # site's cached responses separate instead of collapsing them
    # together across aliases.
    headers         = ["Host"]
    cookies_forward = "whitelist"
    cookies_whitelisted_names = [
      "comment_author_*",
      "wordpress_logged_in_*",
      "wordpress_sec_*",
      "wordpress_no_cache",
      "wordpress_test_cookie",
      "wp-settings-*",
      "wp_woocommerce_session_*",
      "woocommerce_cart_hash",
      "woocommerce_items_in_cart",
      "woocommerce_recently_viewed",
      "AWSALB*",
      "AWSALBCORS*",
    ]
  }

  # No-cache passthrough for always-dynamic, session-specific WordPress and
  # WooCommerce endpoints – never share these responses between visitors.
  wordpress_no_cache_behavior = {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0

    use_forwarded_values = true
    query_string         = true
    # See default_cache_behavior above -- wp-admin/wp-login/xmlrpc are
    # also per-site and need the real Host header to reach the right blog.
    headers         = ["Host"]
    cookies_forward = "all"
  }

  # Long-TTL caching for static, content-addressed WordPress assets.
  wordpress_static_asset_behavior = {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000

    use_forwarded_values = true
    query_string         = false
    # Without forwarding Host, CloudFront sends the origin's own domain name
    # (origin.<env>.wp.<domain>) to the ALB instead of the real site host,
    # which doesn't match the ingress's host-based routing rule and errors.
    headers         = ["Host"]
    cookies_forward = "none"
  }

  # Ordered cache behaviors implementing the strategy above. The ALB remains
  # the origin for the environment CloudFront distribution; uploads have a
  # separate CDN distribution and hostname.
  ordered_cache_behavior = concat(
    [
      for path_pattern in [
        "/wp-admin/*",
        "/wp-login.php",
        "/xmlrpc.php",
        "/wp-json/*",
        "/wc-api/*",
        "/cart*",
        "/checkout*",
        "/my-account*",
        ] : merge(local.wordpress_no_cache_behavior, {
        path_pattern     = path_pattern
        target_origin_id = "alb"
      })
    ],
    [
      for path_pattern in [
        "/wp-content/uploads/*",
        "/wp-content/themes/*",
        "/wp-content/plugins/*",
        "/wp-includes/*",
        ] : merge(local.wordpress_static_asset_behavior, {
        path_pattern     = path_pattern
        target_origin_id = "alb"
      })
    ]
  )

  viewer_certificate = {
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  geo_restriction = {
    restriction_type = "none"
    locations        = []
  }
}
