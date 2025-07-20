variable "execution_role_arn" {
  description = "Docker image URI for the payment service"
  type        = string
}

variable "vpc_id" {
  type        = string
  description = "value"
}

variable "private_subnets" {
  description = "List of VPC security group IDs to associate with the RDS instance."
  type        = list(string)
}

