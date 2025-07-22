
# 1) IAM role that API Gateway will assume to call Step Functions
resource "aws_iam_role" "apigw_sfn_role" {
  name = "apigateway-stepfunctions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}

# 2) Grant that role permission to start your state machine
resource "aws_iam_role_policy" "apigw_sfn_policy" {
  name = "apigateway-start-execution"
  role = aws_iam_role.apigw_sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = [var.aws_sfn_state_machine_order_saga]
    }]
  })

}

# 3) Create the HTTP API
resource "aws_apigatewayv2_api" "orders_api" {
  name          = "orders-saga-api"
  protocol_type = "HTTP"
  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}

# 4) Integration pointing at Step Functions StartExecution action
resource "aws_apigatewayv2_integration" "orders_integration" {
  api_id              = aws_apigatewayv2_api.orders_api.id
  integration_type    = "AWS_PROXY"                    # must be AWS_PROXY
  integration_subtype = "StepFunctions-StartExecution" # and only valid with AWS_PROXY
  #   integration_method     = "POST"
  credentials_arn        = aws_iam_role.apigw_sfn_role.arn
  payload_format_version = "1.0"

  # Map the client’s POST body to the StartExecution call
  request_parameters = {
    StateMachineArn = var.aws_sfn_state_machine_order_saga
    Input           = "$request.body"
  }
}

# 5) Route that listens on POST /order and forwards to the above integration
resource "aws_apigatewayv2_route" "start_route" {
  api_id    = aws_apigatewayv2_api.orders_api.id
  route_key = "POST /order"
  target    = "integrations/${aws_apigatewayv2_integration.orders_integration.id}"
}

# 6) $default stage, auto‑deploy on changes
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.orders_api.id
  name        = "$default"
  auto_deploy = true
}
