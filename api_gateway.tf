# AWS WAFv2 Web ACL for Geolocation filtering
resource "aws_wafv2_web_acl" "example_acl" {
  name        = "${var.company}-${var.environment}-waf-acl"
  description = "Web ACL with geolocation rule"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AllowOnlyHungary"
    priority = 1

    action {
      allow {}
    }

    statement {
      geo_match_statement {
        country_codes = ["HU"]
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "AllowOnlyHungary"
      sampled_requests_enabled   = false
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "${var.company}-${var.environment}-waf-acl"
    sampled_requests_enabled   = false
  }
}

# Associate WAF Web ACL with the specific stage of the API Gateway
resource "aws_wafv2_web_acl_association" "example_association" {
  resource_arn = "${aws_api_gateway_deployment.deployment.execution_arn}/${var.environment}"
  web_acl_arn  = aws_wafv2_web_acl.example_acl.arn
}
