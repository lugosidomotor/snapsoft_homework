# Create a WAF Web ACL
resource "aws_wafv2_web_acl" "web_acl" {
  name        = "${var.company}-${var.environment}-web-acl"
  description = "Web ACL for API Gateway"
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
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowOnlyHungary"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "${var.company}-${var.environment}-web-acl"
    sampled_requests_enabled   = false
  }
}

# Associate the WAF Web ACL with the API Gateway
resource "aws_api_gateway_stage" "stage" {
  stage_name    = aws_api_gateway_deployment.deployment.stage_name
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deployment.id

  web_acl_arn = aws_wafv2_web_acl.web_acl.arn
}
