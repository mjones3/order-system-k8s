variable "order_service_image" {
  description = "Docker image URI for the payment service"
  type        = string
}

variable "execution_role_arn" {
  description = "Docker image URI for the payment service"
  type        = string
}

variable "private_subnets" {
  description = "List of VPC security group IDs to associate with the RDS instance."
  type        = list(string)
}

variable "public_subnets" {
  description = "List of VPC security group IDs to associate with the RDS instance."
  type        = list(string)
}

variable "fargate_cluster" {
  description = "Fargate cluster id"
  type        = string
}

variable "vpc_endpoint_sg" {
  description = "VPC security groups"
  type        = string
}


variable "fargate_sg" {
  description = "Fargate security groups"
  type        = string
}

variable "vpc_id" {
  description = "VPC Id"
  type        = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}

variable "rds_endpoint" {
  type = string
}
