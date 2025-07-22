output "orders_api_endpoint" {
  description = "The endpoint for the orders API"
  value       = aws_apigatewayv2_api.orders_api.api_endpoint
}
