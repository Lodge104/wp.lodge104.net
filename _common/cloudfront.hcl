# -----------------------------------------------------------------------------
# cloudfront – WordPress CloudFront distribution in front of the ALB origin
# (origin.<env>.wp.<domain>), with WAF, static-asset cache policy and branded
# 502/503/403 error pages.
#
# Env-level knobs (<env>/env.hcl):
#   serves_root_domain              also alias <domain>, www.<domain>,
#                                   store.<domain>
#   cloudfront_origin_read_timeout  ALB origin read timeout in seconds
#                                   (default: 60)
#   cloudfront_access_logs          standard access logs to the env's
#                                   cloudfront-logs stack (default: false;
#                                   <env>/<region>/cloudfront-logs must exist)
#
# Full Terragrunt fragment included by <env>/<region>/cloudfront/
# terragrunt.hcl. Env shims only carry real overrides in `inputs`.
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
  ctx = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals

  origin_read_timeout = try(local.ctx.env_vars.cloudfront_origin_read_timeout, 60)
  access_logs         = try(local.ctx.env_vars.cloudfront_access_logs, false)

  # Multisite "store" site shares this distribution/origin. The legacy
  # cdn.<domain> alias remains on the separate media distribution
  # (_common/cdn.hcl).
  aliases = concat(
    [local.ctx.env_domain, "store.${local.ctx.env_domain}"],
    local.ctx.serves_root_domain ? [local.ctx.domain, "www.${local.ctx.domain}", "store.${local.ctx.domain}"] : [],
  )

  # Shared https-only custom origin settings (ALB + error-page origins).
  https_origin = {
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "https-only"
    origin_ssl_protocols   = ["TLSv1.2"]
  }

  price_class = "PriceClass_100" # US, Canada, Europe

  is_ipv6_enabled     = true
  http_version        = "http2and3"
  wait_for_deployment = false

  # Default cache behavior – front-end pages, comments, REST API.
  default_cache_behavior = {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    min_ttl     = 0
    default_ttl = 30
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
    #
    # User-Agent is forwarded too: CloudFront's legacy forwarded_values
    # model replaces any header not in this whitelist with a fixed
    # placeholder value sent to the origin -- for User-Agent that
    # placeholder is the literal string "Amazon CloudFront". Defender
    # Security's bot/lockout logging (and anything else UA-dependent)
    # was logging every single visitor as that one fake user agent
    # instead of their real browser/bot UA. Folding User-Agent into the
    # cache key further fragments the already-short 30s micro-cache, but
    # that's an acceptable trade-off for correct bot detection.
    headers         = ["Host", "User-Agent"]
    cookies_forward = "whitelist"
    # Load-balancer affinity cookies are deliberately NOT whitelisted:
    # every viewer gets a different affinity cookie value, and forwarded
    # cookies are part of the legacy cache key, so including them gave each
    # visitor a private cache entry (~10% HTML hit ratio measured in prod
    # CloudFront logs). Stickiness is only needed for the session-specific
    # behaviors (wp-admin, wp-login, wp-json, cart/checkout/my-account),
    # which forward all cookies via wordpress_no_cache_behavior.
    cookies_whitelisted_names = [
      "comment_author_*",
      "wordpress_logged_in_*",
      "wordpress_sec_*",
      "wordpress_no_cache",
      "wp-settings-*",
      "wp_woocommerce_session_*",
      "woocommerce_cart_hash",
      "woocommerce_items_in_cart",
      "woocommerce_recently_viewed",
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
    # also per-site and need the real Host header to reach the right blog,
    # and User-Agent needs to be forwarded so Defender Security's login
    # lockout/bot logging on wp-login.php sees the real visitor UA instead
    # of CloudFront's "Amazon CloudFront" placeholder. No caching happens
    # on this behavior (max_ttl = 0), so there's no cache-key fragmentation
    # cost to worry about here.
    #
    # Authorization is forwarded so cookie-less clients (WooCommerce mobile
    # app, other REST consumers using Application Passwords) can send HTTP
    # Basic auth to /wp-json/*; legacy forwarded_values drops it otherwise.
    headers         = ["Host", "User-Agent", "Authorization"]
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

  error_page_behavior = {
    viewer_protocol_policy = "https-only"
    compress               = true
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    min_ttl                = 0
    default_ttl            = 60
    max_ttl                = 300
    use_forwarded_values   = true
    query_string           = false
    cookies_forward        = "none"
  }

  error_page_origins = {
    error_502 = {
      domain_name = "aesthetic-brigadeiros-9506ea.netlify.app"
    }
    error_503 = {
      domain_name = "elegant-squirrel-53e205.netlify.app"
    }
    error_403 = {
      domain_name = "tubular-hummingbird-cbcd8e.netlify.app"
    }
  }

  custom_error_response = [
    {
      error_code            = 502
      response_code         = 502
      response_page_path    = "/502"
      error_caching_min_ttl = 0
    },
    {
      error_code            = 503
      response_code         = 503
      response_page_path    = "/503"
      error_caching_min_ttl = 0
    },
    {
      error_code            = 403
      response_code         = 403
      response_page_path    = "/403"
      error_caching_min_ttl = 0
    }
  ]

  # Ordered cache behaviors implementing the strategy above. The ALB remains
  # the origin for the environment CloudFront distribution; uploads have a
  # separate CDN distribution and hostname.
  ordered_cache_behavior = concat(
    [
      merge(local.error_page_behavior, {
        path_pattern     = "/502"
        target_origin_id = "error-502"
      }),
      merge(local.error_page_behavior, {
        path_pattern     = "/503"
        target_origin_id = "error-503"
      }),
      merge(local.error_page_behavior, {
        path_pattern     = "/403"
        target_origin_id = "error-403"
      })
    ],
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

terraform {
  source = "tfr:///terraform-aws-modules/cloudfront/aws?version=3.4.1"
}

dependency "acm" {
  config_path = "../acm"

  mock_outputs = {
    acm_certificate_arn = "arn:aws:acm:${local.ctx.region}:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "static_assets_cache_policy" {
  config_path = "../cloudfront-cache-policy"

  mock_outputs = {
    id = "mock-response-headers-policy-id"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "waf" {
  config_path = "../cloudfront-waf"

  mock_outputs = {
    web_acl_arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/mock/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# Only wired up when cloudfront_access_logs = true (disabled dependencies are
# not added to the run graph and resolve to their mocks).
dependency "logs" {
  enabled     = local.access_logs
  config_path = "../cloudfront-logs"

  mock_outputs = {
    bucket_domain_name = "mock-cloudfront-logs.s3.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = local.ctx.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = merge(
  {
    comment = "${local.ctx.project} ${local.ctx.env} distribution"
    aliases = local.aliases

    price_class         = local.price_class
    is_ipv6_enabled     = local.is_ipv6_enabled
    http_version        = local.http_version
    wait_for_deployment = local.wait_for_deployment
    geo_restriction     = local.geo_restriction

    viewer_certificate = merge(local.viewer_certificate, {
      acm_certificate_arn = dependency.acm.outputs.acm_certificate_arn
    })

    origin = {
      alb = {
        # A DNS alias to the ALB, covered by the *.<env>.wp.<domain> ACM
        # wildcard cert (see _common/route53.hcl) – CloudFront's HTTPS
        # handshake to a custom origin validates the cert against the origin
        # domain name, which the ALB's own auto-generated hostname is never
        # covered by.
        domain_name = "origin.${local.ctx.env_domain}"
        custom_origin_config = merge(local.https_origin, {
          # Reuse persistent connections to the ALB instead of a fresh
          # TCP+TLS handshake per cache-miss request (AWS max is 60s).
          origin_keepalive_timeout = 60
          origin_read_timeout      = local.origin_read_timeout
        })
      }
      error-502 = {
        domain_name          = local.error_page_origins.error_502.domain_name
        custom_origin_config = local.https_origin
      }
      error-503 = {
        domain_name          = local.error_page_origins.error_503.domain_name
        custom_origin_config = local.https_origin
      }
      error-403 = {
        domain_name          = local.error_page_origins.error_403.domain_name
        custom_origin_config = local.https_origin
      }
    }

    default_cache_behavior = merge(local.default_cache_behavior, {
      target_origin_id = "alb"
    })

    # Force long-lived Cache-Control on the static-asset behaviors (max_ttl
    # a year, see wordpress_static_asset_behavior above); leave the always-
    # dynamic no-cache behaviors (max_ttl = 0) untouched.
    ordered_cache_behavior = concat(
      [merge(local.error_page_behavior, {
        path_pattern     = "/.well-known/*"
        target_origin_id = "alb"
      })],
      [
        for behavior in local.ordered_cache_behavior : merge(
          behavior,
          lookup(behavior, "max_ttl", 0) >= 86400 ? {
            response_headers_policy_id = dependency.static_assets_cache_policy.outputs.id
          } : {}
        )
      ]
    )
    custom_error_response = local.custom_error_response
    web_acl_id            = dependency.waf.outputs.web_acl_arn
  },
  # Standard access logs (status, time-taken, edge result type, cache
  # hit/miss) for debugging edge-side failures such as issue #40; WAF logs
  # carry no response status. Cookies are not logged (they hold session
  # tokens). Objects expire after 30 days (see _modules/cloudfront-logs).
  local.access_logs ? {
    logging_config = {
      bucket          = dependency.logs.outputs.bucket_domain_name
      prefix          = "${local.ctx.env}/"
      include_cookies = false
    }
  } : {},
)
