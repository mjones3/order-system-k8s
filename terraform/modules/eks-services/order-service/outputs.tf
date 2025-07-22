output "service_name" {
  description = "Name of the Kubernetes service"
  value       = kubernetes_service.order_service.metadata[0].name
}

output "namespace" {
  description = "Namespace where the service is deployed"
  value       = kubernetes_namespace.order_service.metadata[0].name
}

output "service_endpoint" {
  description = "Internal service endpoint"
  value       = "${kubernetes_service.order_service.metadata[0].name}.${kubernetes_namespace.order_service.metadata[0].name}.svc.cluster.local"
}
