output "service_endpoint" {
  description = "The endpoint of the order service"
  value       = "${kubernetes_service.order_service.metadata[0].name}.${kubernetes_service.order_service.metadata[0].namespace}.svc.cluster.local"
}