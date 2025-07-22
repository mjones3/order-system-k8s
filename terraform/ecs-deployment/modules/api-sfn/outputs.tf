output "orders_api_endpoint" {
  description = "Invoke URL for the orders saga API (POST /start)"
  # the HTTP API endpoint, e.g. https://abcd1234.execute-api.us-east-1.amazonaws.com
  value = aws_apigatewayv2_api.orders_api.api_endpoint
}
