resource "kubernetes_ingress_v1" "payment_service_ingress" {
  depends_on = [kubernetes_deployment.payment_service]

  metadata {
    name      = "payment-service-ingress"
    namespace = kubernetes_namespace.payment_service.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                            = "alb"
      "alb.ingress.kubernetes.io/scheme"                       = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"                  = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path"             = "/actuator/health"
      "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "15"
      "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "5"
      "alb.ingress.kubernetes.io/success-codes"                = "200"
      "alb.ingress.kubernetes.io/healthy-threshold-count"      = "2"
      "alb.ingress.kubernetes.io/unhealthy-threshold-count"    = "2"
      "alb.ingress.kubernetes.io/group.name"                   = "payment-system"
      "alb.ingress.kubernetes.io/listen-ports"                 = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/tags"                         = "Environment=production,Project=payment-system"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.payment_service.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

output "ingress_hostname" {
  description = "The hostname of the ALB created by the ingress"
  value       = try(kubernetes_ingress_v1.payment_service_ingress.status.0.load_balancer.0.ingress.0.hostname, "")
}
