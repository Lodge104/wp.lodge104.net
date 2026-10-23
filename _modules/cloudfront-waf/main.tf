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
