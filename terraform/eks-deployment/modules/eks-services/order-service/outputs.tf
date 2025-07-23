output "service_endpoint" {
  description = "The internal endpoint of the order service"
  value       = "${kubernetes_service.order_service.metadata[0].name}.${kubernetes_service.order_service.metadata[0].namespace}.svc.cluster.local"
}

output "alb_endpoint" {
  description = "The ALB endpoint for the order service"
  value       = "http://${kubernetes_ingress_v1.order_service_ingress.status.0.load_balancer.0.ingress.0.hostname}/api/orders"
}
