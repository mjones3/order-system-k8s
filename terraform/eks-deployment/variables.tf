variable "order_service_image" {
  description = "Docker image URI for the order service"
  type        = string
}

variable "inventory_service_image" {
  description = "Docker image URI for the inventory service"
  type        = string
}

variable "payment_service_image" {
  description = "Docker image URI for the payment service"
  type        = string
}

variable "db_password" {
  description = "Database password for all services"
  type        = string
  sensitive   = true
  default     = "secretpassword"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}
