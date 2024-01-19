resource "aws_api_gateway_rest_api" "dnsdetectives_api" {
  name        = "dnsdetectives_api"
  description = "API Gateway for Lambda example"
}

resource "aws_api_gateway_resource" "dnsdetectives_resource" {
  rest_api_id = aws_api_gateway_rest_api.dnsdetectives_api.id
  parent_id   = aws_api_gateway_rest_api.dnsdetectives_api.root_resource_id
  path_part   = "dnsdetectives-path"
}

resource "aws_api_gateway_method" "dnsdetectives_method" {
  rest_api_id   = aws_api_gateway_rest_api.dnsdetectives_api.id
  resource_id   = aws_api_gateway_resource.dnsdetectives_resource.id
  http_method   = "POST" // Or POST, depending on your Lambda function
  authorization = "NONE"
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
  stage_name  = "test"
}
