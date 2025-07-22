








# Create the ECS Service that runs the task in the Fargate cluster
# resource "aws_ecs_service" "order_service" {
#   name            = "order-service"
#   cluster         = var.fargate_cluster
#   task_definition = aws_ecs_task_definition.order_service.arn
#   desired_count   = 2
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets          = var.private_subnets # List of subnet IDs (typically private subnets)
#     security_groups  = [var.fargate_sg, aws_security_group.ecs_task_sg.id]
#     assign_public_ip = false
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.order_tg.arn
#     container_name   = "order-container"
#     container_port   = 8080
#   }

#   depends_on = [
#     aws_lb_listener.order_listener # Ensure listener exists first
#   ]
# }

# resource "aws_ecs_task_definition" "order_service" {
#   family                   = "order-service"
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   cpu                      = "256"
#   memory                   = "512"
#   execution_role_arn       = var.execution_role_arn # Provided from IAM module
#   task_role_arn            = var.execution_role_arn # Provided from IAM module


#   container_definitions = jsonencode([
#     {
#       name      = "order-container"
#       image     = var.order_service_image
#       essential = true
#       portMappings = [
#         {
#           containerPort = 8080
#           hostPort      = 8080
#           protocol      = "tcp"
#         }
#       ],
#       environment = [
#         {
#           name  = "RDS_ENDPOINT"
#           value = var.rds_endpoint
#         },
#         {
#           name  = "DB_NAME"
#           value = var.db_name
#         },
#         {
#           name  = "DB_USERNAME"
#           value = var.db_username
#         },
#         {
#           name  = "DB_PASSWORD"
#           value = var.db_password
#         }
#       ],
#       logConfiguration = {
#         logDriver = "awslogs"
#         options = {
#           "awslogs-group"         = aws_cloudwatch_log_group.ecs_app_log_group.name
#           "awslogs-region"        = "us-east-1"
#           "awslogs-stream-prefix" = "ecs"
#         }
#       }
#     }
#   ])
# }

# resource "aws_security_group" "ecs_task_sg" {
#   name        = "ecs-task-sg"
#   description = "Security group for ECS tasks that allows outbound HTTPS (443) traffic"
#   vpc_id      = var.vpc_id

#   # Allow outbound HTTPS traffic
#   egress {
#     description = "Allow outbound HTTPS traffic on port 443"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # (Optional) If you need inbound rules for your task, add them here.
#   # By default, ECS tasks usually don't receive inbound traffic directly.
#   # You can define inbound rules if your application requires them.

#   tags = {
#     Environment = "dev"
#     project     = "order-system"
#   }
# }


# # Create a security group for the load balancer (adjust rules as needed)
# resource "aws_security_group" "lb_sg" {
#   name        = "order-lb-sg"
#   description = "Security group for the Application Load Balancer"
#   vpc_id      = var.vpc_id

#   ingress {
#     description = "Allow HTTP from anywhere"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     description = "Allow all outbound traffic"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Environment = "dev"
#     project     = "order-system"
#   }
# }

# # Create the Application Load Balancer (ALB)
# resource "aws_lb" "order_lb" {
#   name               = "order-lb"
#   load_balancer_type = "application"
#   subnets            = var.public_subnets # Public subnets for ALB
#   security_groups    = [aws_security_group.lb_sg.id]

#   tags = {
#     Environment = "dev"
#     project     = "order-system"
#   }
# }


# # Create a target group for your ECS tasks
# resource "aws_lb_target_group" "order_tg" {
#   name        = "order-tg"
#   port        = 8080
#   protocol    = "HTTP"
#   target_type = "ip" # For Fargate tasks, use "ip" as target type
#   vpc_id      = var.vpc_id

#   health_check {
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     interval            = 90
#     timeout             = 5
#     path                = "/actuator/health"
#     matcher             = "200-299"
#   }

#   tags = {
#     Environment = "dev"
#     project     = "order-system"
#   }
# }

# # Create a listener for the ALB that forwards traffic to the target group
# resource "aws_lb_listener" "order_listener" {
#   load_balancer_arn = aws_lb.order_lb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.order_tg.arn

#   }
#   tags = {
#     Environment = "dev"
#     project     = "order-system"
#   }

# }

# resource "aws_cloudwatch_log_group" "ecs_app_log_group" {
#   name              = "/ecs/order-service"
#   retention_in_days = 30
#   tags = {
#     Environment = "dev"
#     project     = "order-system"
#   }
# }
