output "fargate_cluster" {
  description = "The ARN of the ECS Task Execution Role"
  value       = aws_ecs_cluster.fargate_cluster.id
}
