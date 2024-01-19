output "api_gateway_endpoint" {
  value = "https://${aws_api_gateway_rest_api.dnsdetectives_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_deployment.dnsdetectives_deployment.stage_name}/dnsdetectives-path"
}

output "api_key" {
  value = aws_api_gateway_api_key.example_api_key.value
  sensitive = true
}
