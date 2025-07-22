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
