# EKS Inventory Service Deployment
resource "kubernetes_namespace" "inventory_service" {
  metadata {
    name = "inventory-service"
    labels = {
      name = "inventory-service"
    }
  }
}

# ConfigMap for inventory service
resource "kubernetes_config_map" "inventory_service_config" {
  metadata {
    name      = "inventory-service-config"
    namespace = kubernetes_namespace.inventory_service.metadata[0].name
  }

  data = {
    PG_CONTAINER    = "postgres-inventorydb"
    DATASOURCE_PORT = "5432"
    ENVIRONMENT     = "production"
    PG_DB           = var.db_name
    PG_USER         = var.db_username
    PG_PASS         = var.db_password
    PG_PORT         = "5432"
    DATASOURCE_URL  = "jdbc:postgresql://${var.rds_endpoint}:5432/${var.db_name}"
  }
}

# Deployment for inventory service
resource "kubernetes_deployment" "inventory_service" {
  metadata {
    name      = "inventory-service"
    namespace = kubernetes_namespace.inventory_service.metadata[0].name
    labels = {
      app = "inventory-service"
    }
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = {
        app = "inventory-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "inventory-service"
        }
      }

      spec {
        container {
          image = var.inventory_service_image
          name  = "inventory-service"

          port {
            container_port = 8080
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.inventory_service_config.metadata[0].name
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

# Service for inventory service
resource "kubernetes_service" "inventory_service" {
  metadata {
    name      = "inventory-service"
    namespace = kubernetes_namespace.inventory_service.metadata[0].name
  }

  spec {
    selector = {
      app = "inventory-service"
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
resource "kubernetes_horizontal_pod_autoscaler_v2" "inventory_service_hpa" {
  metadata {
    name      = "inventory-service-hpa"
    namespace = kubernetes_namespace.inventory_service.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.inventory_service.metadata[0].name
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
