resource "aws_api_gateway_rest_api" "dnsdetectives_api" {
  name        = "dnsdetectives_api"
  description = "API Gateway for Lambda example"
}

resource "aws_api_gateway_resource" "dnsdetectives_resource" {
  rest_api_id = aws_api_gateway_rest_api.dnsdetectives_api.id
  parent_id   = aws_api_gateway_rest_api.dnsdetectives_api.root_resource_id
  path_part   = "dnsdetectives-path"
}

resource "aws_api_gateway_model" "example_model" {
  rest_api_id  = aws_api_gateway_rest_api.dnsdetectives_api.id
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
  name                        = "example-validator"
  rest_api_id                 = aws_api_gateway_rest_api.dnsdetectives_api.id
  validate_request_body       = true
  validate_request_parameters = false
}

resource "aws_api_gateway_method" "dnsdetectives_method" {
  rest_api_id          = aws_api_gateway_rest_api.dnsdetectives_api.id
  resource_id          = aws_api_gateway_resource.dnsdetectives_resource.id
  http_method          = "POST"
  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.example_validator.id
}

resource "aws_api_gateway_integration" "dnsdetectives_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.dnsdetectives_api.id
  resource_id             = aws_api_gateway_resource.dnsdetectives_resource.id
  http_method             = aws_api_gateway_method.dnsdetectives_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.dnsdetectives_lambda_function.invoke_arn
}

resource "aws_api_gateway_deployment" "dnsdetectives_deployment" {
  depends_on = [aws_api_gateway_integration.dnsdetectives_lambda_integration]

  rest_api_id = aws_api_gateway_rest_api.dnsdetectives_api.id
  stage_name  = "dev"
}
