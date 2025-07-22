output "order_service_ingress_hostname" {
  description = "The hostname of the ALB created for the order service"
  value       = module.eks_order_service.ingress_hostname
}

output "order_service_url" {
  description = "The URL to access the order service"
  value       = "http://${module.eks_order_service.ingress_hostname}"
}