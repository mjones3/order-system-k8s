variable "ecs_task_execution_role_arn" {
  type        = string
  description = "ARN of the ECS Task Execution Role that can push/pull images"
}

variable "repository_name" {
  type        = string
  description = "value"

}

variable "vpc_endpoint_sg" {
  type        = string
  description = "value"

}

variable "vpc_id" {
  type        = string
  description = "value"

}
variable "private_subnets" {
  description = "List of VPC security group IDs to associate with the RDS instance."
  type        = list(string)
}
