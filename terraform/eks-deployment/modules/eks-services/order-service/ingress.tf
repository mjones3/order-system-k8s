resource "kubernetes_ingress_v1" "order_service_ingress" {
  depends_on = [kubernetes_deployment.order_service]
  
  metadata {
    name      = "order-service-ingress"
    namespace = kubernetes_namespace.order_service.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/actuator/health"
      "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "15"
      "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "5"
      "alb.ingress.kubernetes.io/success-codes"        = "200"
      "alb.ingress.kubernetes.io/healthy-threshold-count"      = "2"
      "alb.ingress.kubernetes.io/unhealthy-threshold-count"    = "2"
      "alb.ingress.kubernetes.io/group.name"           = "order-system"
      "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"         = "443"
      "alb.ingress.kubernetes.io/tags"                 = "Environment=production,Project=order-system"
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
              name = kubernetes_service.order_service.metadata[0].name
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
  value       = kubernetes_ingress_v1.order_service_ingress.status.0.load_balancer.0.ingress.0.hostname
}