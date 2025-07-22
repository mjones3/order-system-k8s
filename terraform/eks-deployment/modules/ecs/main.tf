
resource "aws_ecs_cluster" "fargate_cluster" {
  name = "order-system-fargate-cluster"
  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}

# resource "aws_security_group" "vpc_endpoint_sg" {
#   name        = "vpc-endpoint-sg"
#   description = "Security group for VPC endpoints (ECR, etc.)"
#   vpc_id      = var.vpc_id

#   ingress {
#     description = "Allow inbound HTTPS traffic from ECS tasks"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     # Option A: Restrict to a specific security group (e.g. ECS tasks SG)
#     security_groups = [var.vpc_endpoint_sg]
#     # Option B: Alternatively, allow from your VPC CIDR (uncomment if needed)
#     # cidr_blocks   = [var.vpc_cidr]
#   }

#   egress {
#     description = "Allow all outbound traffic"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Terraform   = "true"
#     Environment = "dev"
#   }
# }
