output "service_name" {
  description = "Name of the Kubernetes service"
  value       = kubernetes_service.payment_service.metadata[0].name
}

output "namespace" {
  description = "Namespace where the service is deployed"
  value       = kubernetes_namespace.payment_service.metadata[0].name
}

output "service_endpoint" {
  description = "Internal service endpoint"
  value       = "${kubernetes_service.payment_service.metadata[0].name}.${kubernetes_namespace.payment_service.metadata[0].name}.svc.cluster.local"
}

output "alb_endpoint" {
  description = "The ALB endpoint for the payment service"
  value       = "http://${kubernetes_ingress_v1.payment_service_ingress.status.0.load_balancer.0.ingress.0.hostname}/api/payments"
}
