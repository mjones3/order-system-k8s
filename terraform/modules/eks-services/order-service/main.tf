# EKS Order Service Deployment
resource "kubernetes_namespace" "order_service" {
  metadata {
    name = "order-service"
    labels = {
      name = "order-service"
    }
  }
}

# ConfigMap for order service
resource "kubernetes_config_map" "order_service_config" {
  metadata {
    name      = "order-service-config"
    namespace = kubernetes_namespace.order_service.metadata[0].name
  }

  data = {
    PG_CONTAINER    = "postgres-orderdb"
    DATASOURCE_PORT = "5432"
    ENVIRONMENT     = "production"
    PG_DB           = var.db_name
    PG_USER         = var.db_username
    PG_PASS         = var.db_password
    PG_PORT         = "5432"
    DATASOURCE_URL  = "jdbc:postgresql://${var.rds_endpoint}:5432/${var.db_name}"
  }
}

# Deployment for order service
resource "kubernetes_deployment" "order_service" {
  metadata {
    name      = "order-service"
    namespace = kubernetes_namespace.order_service.metadata[0].name
    labels = {
      app = "order-service"
    }
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = {
        app = "order-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "order-service"
        }
      }

      spec {
        container {
          image = var.order_service_image
          name  = "order-service"

          port {
            container_port = 8080
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.order_service_config.metadata[0].name
            }
          }

          resources {
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
          }

          liveness_probe {
            http_get {
              path = "/actuator/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/actuator/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }
}

# Service for order service
resource "kubernetes_service" "order_service" {
  metadata {
    name      = "order-service"
    namespace = kubernetes_namespace.order_service.metadata[0].name
  }

  spec {
    selector = {
      app = "order-service"
    }

    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Horizontal Pod Autoscaler
resource "kubernetes_horizontal_pod_autoscaler_v2" "order_service_hpa" {
  metadata {
    name      = "order-service-hpa"
    namespace = kubernetes_namespace.order_service.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.order_service.metadata[0].name
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}
