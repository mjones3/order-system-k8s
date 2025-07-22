

module "ecr_repo" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name                 = var.repository_name
  repository_image_tag_mutability = "MUTABLE"


  # from the variable
  repository_read_write_access_arns = [
    var.ecs_task_execution_role_arn
  ]

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}
