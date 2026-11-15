terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Login brute-force protection. Replaces the lockout feature of the WP
  # Defender plugin (deactivated on prod 2026-11-08 because its Session
  # Protection kept logging users out). Counts login-style POSTs per viewer
  # IP over a sliding window and blocks the IP with a 429 once it exceeds
  # the limit; the block lifts automatically when the rate drops back.
  # Covered endpoints: wp-login.php, xmlrpc.php (credential-guessing via
  # system.multicall) and the WooCommerce /my-account login form used by
  # the store sites. Runs before the managed rule groups (priority 5) so
  # abusive IPs are cut off cheaply.
  rule {
    name     = "LoginRateLimit"
    priority = 5

    action {
      block {
        custom_response {
          response_code = 429
        }
      }
    }

    statement {
      rate_based_statement {
        limit                 = var.login_rate_limit
        evaluation_window_sec = var.login_rate_window_seconds
        aggregate_key_type    = "IP"

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                search_string         = "POST"
                positional_constraint = "EXACTLY"

                field_to_match {
                  method {}
                }

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }

            statement {
              or_statement {
                statement {
                  byte_match_statement {
                    search_string         = "/wp-login.php"
                    positional_constraint = "EXACTLY"

                    field_to_match {
                      uri_path {}
                    }

                    text_transformation {
                      priority = 0
                      type     = "URL_DECODE"
                    }
                  }
                }

                statement {
                  byte_match_statement {
                    search_string         = "/xmlrpc.php"
                    positional_constraint = "EXACTLY"

                    field_to_match {
                      uri_path {}
                    }

                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }

                statement {
                  byte_match_statement {
                    search_string         = "/my-account"
                    positional_constraint = "STARTS_WITH"

                    field_to_match {
                      uri_path {}
                    }

                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-login-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }

        rule_action_override {
          name = "CrossSiteScripting_BODY"
          action_to_use {
            count {}
          }
        }

        rule_action_override {
          name = "GenericLFI_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-common"
      sampled_requests_enabled   = true
    }
  }

  # The managed body rules count globally so that body matches can be
  # blocked on public paths while remaining non-blocking for page-builder
  # requests under /wp-admin. xmlrpc.php is also excluded: its XML-RPC
  # request body is a well-formed XML document (e.g.
  # "<?xml version=\"1.0\"?><methodCall>..."), and the leading "<?xml"
  # reliably false-positives against CrossSiteScripting_BODY, blocking
  # every legitimate XML-RPC call (Jetpack, pingbacks, remote publishing)
  # before it reaches WordPress. Jetpack's signed "comms" sync protocol is
  # excluded too: it POSTs an XML body to "/" (not /xmlrpc.php) with
  # "?jetpack=comms" in the query string, which false-positives the same
  # way and would otherwise block Jetpack's connection/sync traffic.
  rule {
    name     = "CommonRuleSet-body-block-public"
    priority = 11

    action {
      block {}
    }

    # NOTE: AWS WAFv2 (both the API itself and the Terraform provider's
    # unrolled aws_wafv2_web_acl schema) only supports nesting statement
    # blocks (and_statement/or_statement/not_statement) up to 3 levels deep.
    # The "natural" way to express this -- block if a body-rule label fired
    # AND NOT(path is one of "/wp-admin*", "/xmlrpc.php" exactly, OR
    # (path == "/" AND jetpack comms query arg)) -- nests and_statement 4
    # levels deep and fails with "Unsupported block type: Blocks of type
    # \"and_statement\" are not expected here".
    #
    # Rewritten via De Morgan's law to the logically identical form:
    #   NOT(OR(A, B, AND(C, D))) == NOT(A) AND NOT(B) AND (NOT(C) OR NOT(D))
    # which keeps every branch at <= 3 levels of nesting.
    statement {
      and_statement {
        # NOT "/wp-admin*"
        statement {
          not_statement {
            statement {
              byte_match_statement {
                search_string         = "/wp-admin"
                positional_constraint = "STARTS_WITH"

                field_to_match {
                  uri_path {}
                }

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }

        # NOT "/xmlrpc.php" (exact)
        statement {
          not_statement {
            statement {
              byte_match_statement {
                search_string         = "/xmlrpc.php"
                positional_constraint = "EXACTLY"

                field_to_match {
                  uri_path {}
                }

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }

        # NOT (path == "/" AND jetpack query arg == "comms"), expanded to
        # NOT(path == "/") OR NOT(jetpack query arg == "comms")
        statement {
          or_statement {
            statement {
              not_statement {
                statement {
                  byte_match_statement {
                    search_string         = "/"
                    positional_constraint = "EXACTLY"

                    field_to_match {
                      uri_path {}
                    }

                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }

            statement {
              not_statement {
                statement {
                  byte_match_statement {
                    search_string         = "comms"
                    positional_constraint = "EXACTLY"

                    field_to_match {
                      single_query_argument {
                        name = "jetpack"
                      }
                    }

                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
          }
        }

        # NOT (path starts with "/wp-json/" AND wordpress_logged_in_ cookie),
        # expanded to NOT(path) OR NOT(cookie). Lets the block/page editors
        # save content over REST (e.g. POST /wp-json/wp/v2/pages/<id>/autosaves,
        # whose HTML bodies trip the XSS rule) while anonymous REST bodies
        # stay blocked. The cookie is only a presence check, so it can be
        # spoofed; WordPress still enforces real auth.
        statement {
          or_statement {
            statement {
              not_statement {
                statement {
                  byte_match_statement {
                    search_string         = "/wp-json/"
                    positional_constraint = "STARTS_WITH"

                    field_to_match {
                      uri_path {}
                    }

                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }

            statement {
              not_statement {
                statement {
                  byte_match_statement {
                    search_string         = "wordpress_logged_in_"
                    positional_constraint = "CONTAINS"

                    field_to_match {
                      single_header {
                        name = "cookie"
                      }
                    }

                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
          }
        }

        statement {
          or_statement {
            statement {
              label_match_statement {
                scope = "LABEL"
                key   = "awswaf:managed:aws:core-rule-set:SizeRestrictions_Body"
              }
            }

            statement {
              label_match_statement {
                scope = "LABEL"
                key   = "awswaf:managed:aws:core-rule-set:CrossSiteScripting_Body"
              }
            }

            statement {
              label_match_statement {
                scope = "LABEL"
                key   = "awswaf:managed:aws:core-rule-set:GenericLFI_Body"
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-common-body-public"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }
}

# WAF logging requires a CloudWatch Logs log group whose name is prefixed
# with "aws-waf-logs-" and a resource policy granting the WAF logging
# service permission to write to it.
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.name}"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "waf_logging" {
  statement {
    sid    = "AWSWAFLogging"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.waf.arn}:*"]
  }
}

resource "aws_cloudwatch_log_resource_policy" "waf" {
  policy_name     = "${var.name}-waf-logging"
  policy_document = data.aws_iam_policy_document.waf_logging.json
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  depends_on = [aws_cloudwatch_log_resource_policy.waf]
}
