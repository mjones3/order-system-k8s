# Get the EKS cluster VPC ID
data "aws_eks_cluster" "cluster" {
  name = "order-system-cluster"
}

data "aws_vpc" "eks_vpc" {
  id = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
}

# Create a VPC Link for the API Gateway
resource "aws_apigatewayv2_vpc_link" "eks_vpc_link" {
  name               = "order-service-vpc-link"
  security_group_ids = [aws_security_group.api_gateway_sg.id]
  subnet_ids         = data.aws_subnets.private.ids
}

# Get private subnets
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks_vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

# Security group for API Gateway VPC Link
resource "aws_security_group" "api_gateway_sg" {
  name        = "api-gateway-sg"
  description = "Security group for API Gateway VPC Link"
  vpc_id      = data.aws_vpc.eks_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an HTTP API
resource "aws_apigatewayv2_api" "order_api" {
  name          = "order-service-api"
  protocol_type = "HTTP"
}

# Create a stage
resource "aws_apigatewayv2_stage" "order_api_stage" {
  api_id      = aws_apigatewayv2_api.order_api.id
  name        = "prod"
  auto_deploy = true
}

# Create an integration with the EKS service
resource "aws_apigatewayv2_integration" "order_service_integration" {
  api_id             = aws_apigatewayv2_api.order_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://order-service.order-service.svc.cluster.local"
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.eks_vpc_link.id
}

# Create a route
resource "aws_apigatewayv2_route" "order_service_route" {
  api_id    = aws_apigatewayv2_api.order_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.order_service_integration.id}"
}

# Output the API Gateway URL
output "api_gateway_url" {
  value = "${aws_apigatewayv2_stage.order_api_stage.invoke_url}"
}