resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.company}_${var.environment}_api"
  description = "API Gateway for Lambda example"
}

resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "${var.company}-path"
}

resource "aws_api_gateway_model" "example_model" {
  rest_api_id  = aws_api_gateway_rest_api.api.id
  name         = "ExampleModel"
  content_type = "application/json"

  schema = <<SCHEMA
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "ExampleModel",
  "type": "object",
  "properties": {
    "message": {"type": "string"},
    "target": {"type": "string"}
  },
  "required": ["message", "target"]
}
SCHEMA
}

resource "aws_api_gateway_request_validator" "example_validator" {
  name                        = "${var.company}_validator"
  rest_api_id                 = aws_api_gateway_rest_api.api.id
  validate_request_body       = true
  validate_request_parameters = false
}

resource "aws_api_gateway_method" "method" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.resource.id
  http_method          = "POST"
  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.example_validator.id
  api_key_required     = true

  request_models = {
    "application/json" = aws_api_gateway_model.example_model.name
  }
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_api_key" "api_key" {
  name = "${var.company}-${var.environment}-api-key"
}

resource "aws_api_gateway_usage_plan" "usage_plan" {
  name        = "${var.company}-${var.environment}-usage-plan"
  description = "${var.company} usage plan"
  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_deployment.deployment.stage_name
  }

  quota_settings {
    limit  = 1000
    offset = 0
    period = "DAY"
  }

  throttle_settings {
    burst_limit = 20
    rate_limit  = 10
  }
}

resource "aws_api_gateway_usage_plan_key" "usage_plan_key" {
  key_id        = aws_api_gateway_api_key.api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.usage_plan.id
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.environment
}
