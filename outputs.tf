output "api_gateway_endpoint" {
  value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_deployment.deployment.stage_name}/${var.company}-path"
}

output "api_key" {
  value     = aws_api_gateway_api_key.api_key.value
  sensitive = true
}
