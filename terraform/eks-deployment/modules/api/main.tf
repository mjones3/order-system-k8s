# Create the API Gateway (HTTP API)
resource "aws_apigatewayv2_api" "orders_api" {
  name          = "orders-api"
  protocol_type = "HTTP"
  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}

# Create an integration that proxies requests to the load balancer.
# The integration_uri must include the scheme (http:// or https://).
resource "aws_apigatewayv2_integration" "orders_integration" {
  api_id                 = aws_apigatewayv2_api.orders_api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = "http://${var.orders_lb_dns}" # load balancer DNS from order_service module
  payload_format_version = "1.0"
}

# Create a route for GET requests to /orders that forwards to the integration.
resource "aws_apigatewayv2_route" "orders_get" {
  api_id    = aws_apigatewayv2_api.orders_api.id
  route_key = "GET /orders"
  target    = "integrations/${aws_apigatewayv2_integration.orders_integration.id}"
}

# Create a route for POST requests to /orders that forwards to the integration.
resource "aws_apigatewayv2_route" "orders_post" {
  api_id    = aws_apigatewayv2_api.orders_api.id
  route_key = "POST /orders"
  target    = "integrations/${aws_apigatewayv2_integration.orders_integration.id}"
}

# Create a default stage that auto-deploys changes.
resource "aws_apigatewayv2_stage" "orders_stage" {
  api_id      = aws_apigatewayv2_api.orders_api.id
  name        = "$default"
  auto_deploy = true
}

# Create an explicit deployment (this resource captures the current API configuration)
resource "aws_apigatewayv2_deployment" "orders_deployment" {
  api_id = aws_apigatewayv2_api.orders_api.id

  depends_on = [
    aws_apigatewayv2_route.orders_get,
    aws_apigatewayv2_route.orders_post,
  ]
}

resource "aws_cloudwatch_log_group" "apigw_logs" {
  name              = "/aws/apigateway/orders-api-logs"
  retention_in_days = 14

  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}


# Create a stage for the dev environment, manually referencing the deployment
resource "aws_apigatewayv2_stage" "orders_stage_dev" {
  api_id        = aws_apigatewayv2_api.orders_api.id
  name          = "dev"
  deployment_id = aws_apigatewayv2_deployment.orders_deployment.id
  auto_deploy   = false # Set to false to use manual deployments; change to true for auto-deploy

  # Optional: Configure logging and variables for the stage
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_logs.arn
    format = jsonencode({
      requestId    = "$context.requestId",
      ip           = "$context.identity.sourceIp",
      caller       = "$context.identity.caller",
      user         = "$context.identity.user",
      requestTime  = "$context.requestTime",
      httpMethod   = "$context.httpMethod",
      resourcePath = "$context.resourcePath",
      status       = "$context.status",
      protocol     = "$context.protocol"
    })
  }
}
