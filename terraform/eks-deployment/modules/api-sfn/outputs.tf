output "api_endpoint" {
  description = "The API Gateway endpoint URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  description = "The API Gateway ID"
  value       = aws_apigatewayv2_api.orders_api.id
}

output "stage_name" {
  description = "The API Gateway stage name"
  value       = aws_apigatewayv2_stage.default.name
}
