variable "payment_service_image" {
  description = "Docker image URI for the payment service"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "paymentdb"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "paymentuser"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "rds_endpoint" {
  description = "RDS endpoint for the database"
  type        = string
}

variable "replica_count" {
  description = "Number of replicas for the deployment"
  type        = number
  default     = 2
}

variable "cpu_limit" {
  description = "CPU limit for the container"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for the container"
  type        = string
  default     = "512Mi"
}

variable "cpu_request" {
  description = "CPU request for the container"
  type        = string
  default     = "250m"
}

variable "memory_request" {
  description = "Memory request for the container"
  type        = string
  default     = "256Mi"
}

variable "min_replicas" {
  description = "Minimum number of replicas for HPA"
  type        = number
  default     = 2
}

variable "max_replicas" {
  description = "Maximum number of replicas for HPA"
  type        = number
  default     = 10
}
