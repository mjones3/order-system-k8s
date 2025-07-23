output "order_service_ingress_hostname" {
  description = "The hostname of the ALB created for the order service"
  value       = module.eks_order_service.ingress_hostname
}

output "order_service_url" {
  description = "The URL to access the order service"
  value       = "http://${module.eks_order_service.ingress_hostname}"
}

output "inventory_service_ingress_hostname" {
  description = "The hostname of the ALB created for the inventory service"
  value       = module.eks_inventory_service.ingress_hostname
}

output "inventory_service_url" {
  description = "The URL to access the inventory service"
  value       = "http://${module.eks_inventory_service.ingress_hostname}"
}

output "payment_service_ingress_hostname" {
  description = "The hostname of the ALB created for the payment service"
  value       = module.eks_payment_service.ingress_hostname
}

output "payment_service_url" {
  description = "The URL to access the payment service"
  value       = "http://${module.eks_payment_service.ingress_hostname}"
}
