# 1) An IAM policy document that allows ECS tasks to assume the role.
data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}


#Elastic Kubernetes Service
resource "aws_iam_role" "eks_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Effect = "Allow"
      },
    ]
  })

  tags = {
    Name = "eks-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}


# Security groups are managed by the EKS module and network module




resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecsTaskExecution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json
}

# 3) Attach the AWS-managed policy that covers:
#    - Pulling images from ECR
#    - Sending logs to CloudWatch
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach the AWS X-Ray policy to the ECS task execution role
resource "aws_iam_role_policy_attachment" "xray_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Additional custom policies (e.g., for SQS)
resource "aws_iam_role_policy" "ecs_task_execution_sqs_policy" {
  name = "ecs-task-execution-sqs-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sqs:SendMessage",
        Resource = "arn:aws:sqs:us-east-1:294417223953:orders-queue"
      }
    ]
  })
}

resource "aws_iam_role" "sfn_role" {
  name = "order-saga-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "states.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
  tags = {
    Environment = "dev"
    project     = "order-system"
  }

  # Handle existing resources gracefully
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      # Ignore changes to tags
      tags,
      # Ignore changes to the assume role policy
      assume_role_policy
    ]
  }
}

resource "aws_iam_role_policy_attachment" "sfn_xray_policy" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# The IAM role Lambda will assume
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = "dev"
    project     = "order-system"
  }

  # Handle existing resources gracefully
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      # Ignore changes to tags
      tags,
      # Ignore changes to the assume role policy
      assume_role_policy
    ]
  }
}

# Attach the AWS X-Ray policy to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_xray_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}


resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "sfn_policy" {
  name = "order-saga-sfn-policy"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = [
          var.aws_lambda_function_order_service_arn,
          var.aws_lambda_function_inventory_service_arn,
          var.aws_lambda_function_payment_service_arn,
          var.aws_lambda_function_release_inventory_arn,
          var.aws_lambda_function_cancel_order_arn,
        ]
      }
    ]
  })
}
