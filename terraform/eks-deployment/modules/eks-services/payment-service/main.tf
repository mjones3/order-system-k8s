# EKS Payment Service Deployment
resource "kubernetes_namespace" "payment_service" {
  metadata {
    name = "payment-service"
    labels = {
      name = "payment-service"
    }
  }
}

# ConfigMap for payment service
resource "kubernetes_config_map" "payment_service_config" {
  metadata {
    name      = "payment-service-config"
    namespace = kubernetes_namespace.payment_service.metadata[0].name
  }

  data = {
    # Database connection information
    PG_HOST         = var.rds_endpoint
    PG_CONTAINER    = "postgres-paymentdb" # Kept for backward compatibility
    DATASOURCE_PORT = "5432"
    ENVIRONMENT     = "production"
    PG_DB           = var.db_name
    PG_USER         = var.db_username
    PG_PASS         = var.db_password
    PG_PORT         = "5432"

    # Spring Boot specific configuration
    SPRING_PROFILES_ACTIVE     = "production"
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${var.rds_endpoint}:5432/${var.db_name}"
    SPRING_DATASOURCE_USERNAME = var.db_username
    SPRING_DATASOURCE_PASSWORD = var.db_password

    # Actuator configuration
    MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE = "*"
    MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS   = "always"
    MANAGEMENT_ENDPOINTS_WEB_BASE_PATH        = "/actuator"

    # Standard JDBC URL for other frameworks
    DATASOURCE_URL = "jdbc:postgresql://${var.rds_endpoint}:5432/${var.db_name}"

    # Flag to indicate environment
    DEPLOYMENT_ENV = "cloud"
  }
}

# Deployment for payment service
resource "kubernetes_deployment" "payment_service" {
  metadata {
    name      = "payment-service"
    namespace = kubernetes_namespace.payment_service.metadata[0].name
    labels = {
      app     = "payment-service"
      version = "v1"
      part-of = "payment-system"
    }
    annotations = {
      "kubernetes.io/description"  = "Payment service for processing payments"
      "kubernetes.io/change-cause" = "Initial deployment of payment service"
    }
  }

  spec {
    replicas = var.replica_count

    # Strategy for rolling updates
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "25%"
        max_unavailable = "25%"
      }
    }

    selector {
      match_labels = {
        app = "payment-service"
      }
    }

    template {
      metadata {
        labels = {
          app     = "payment-service"
          version = "v1"
          part-of = "payment-system"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8080"
          "prometheus.io/path"   = "/actuator/prometheus"
        }
      }

      spec {
        # Ensure pods are scheduled to different nodes
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["payment-service"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        # Tolerations to ensure pods can be scheduled even on tainted nodes if necessary
        toleration {
          key                = "node.kubernetes.io/not-ready"
          operator           = "Exists"
          effect             = "NoExecute"
          toleration_seconds = 300
        }

        toleration {
          key                = "node.kubernetes.io/unreachable"
          operator           = "Exists"
          effect             = "NoExecute"
          toleration_seconds = 300
        }

        # Init container to check database connectivity
        init_container {
          name  = "init-db-check"
          image = "postgres:14-alpine"
          command = [
            "sh", "-c",
            "until pg_isready -h ${split(":", var.rds_endpoint)[0]} -p 5432; do echo waiting for database; sleep 2; done;"
          ]
          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }
        }

        # Init container to check DNS resolution
        init_container {
          name  = "init-dns-check"
          image = "busybox:1.36"
          command = [
            "sh", "-c",
            "until nslookup kubernetes.default.svc.cluster.local; do echo waiting for DNS; sleep 2; done;"
          ]
          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }
        }

        container {
          image             = var.payment_service_image
          image_pull_policy = "Always" # Always pull the latest image
          name              = "payment-service"

          # Container security context
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          port {
            name           = "http"
            container_port = 8080
          }

          # Environment variables
          env_from {
            config_map_ref {
              name = kubernetes_config_map.payment_service_config.metadata[0].name
            }
          }

          # Add specific environment variables
          env {
            name  = "SPRING_PROFILES_ACTIVE"
            value = "production"
          }

          env {
            name  = "SERVER_PORT"
            value = "8080"
          }

          env {
            name  = "JAVA_OPTS"
            value = "-Xms256m -Xmx512m -XX:+UseG1GC"
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

          # Startup probe to handle slow-starting containers
          # This is checked before liveness and readiness probes
          startup_probe {
            http_get {
              path = "/actuator/health"
              port = 8080
              http_header {
                name  = "Accept"
                value = "application/json"
              }
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 30 # Allow up to 5 minutes (30 * 10s) for startup
            success_threshold     = 1
          }

          # Liveness probe - checks if the application is running
          liveness_probe {
            http_get {
              path = "/actuator/health/liveness"
              port = 8080
              http_header {
                name  = "Accept"
                value = "application/json"
              }
            }
            initial_delay_seconds = 60 # Start checking after startup probe succeeds
            period_seconds        = 15 # Check every 15 seconds
            timeout_seconds       = 5  # Timeout after 5 seconds
            failure_threshold     = 3  # Allow 3 failures before restarting
            success_threshold     = 1  # One success is enough
          }

          # Readiness probe - checks if the application is ready to serve traffic
          readiness_probe {
            http_get {
              path = "/actuator/health/readiness"
              port = 8080
              http_header {
                name  = "Accept"
                value = "application/json"
              }
            }
            initial_delay_seconds = 30 # Start checking after 30 seconds
            period_seconds        = 10 # Check every 10 seconds
            timeout_seconds       = 3  # Timeout after 3 seconds
            failure_threshold     = 3  # Allow 3 failures before marking as not ready
            success_threshold     = 1  # One success is enough
          }

          # Volume mounts for logs and config
          volume_mount {
            name       = "logs"
            mount_path = "/app/logs"
          }

          # Lifecycle hooks
          lifecycle {
            pre_stop {
              exec {
                command = ["/bin/sh", "-c", "sleep 10 && curl -X POST http://localhost:8080/actuator/shutdown || true"] # Grace period for connections to drain and graceful shutdown
              }
            }
          }
        }

        # Volumes
        volume {
          name = "logs"
          empty_dir {}
        }

        # Pod security context
        security_context {
          fs_group        = 1000
          run_as_non_root = true
          run_as_user     = 1000
        }

        # Termination grace period - allow time for connections to drain
        termination_grace_period_seconds = 60
      }
    }
  }
}

# Service for payment service
resource "kubernetes_service" "payment_service" {
  metadata {
    name      = "payment-service"
    namespace = kubernetes_namespace.payment_service.metadata[0].name
    labels = {
      app     = "payment-service"
      part-of = "payment-system"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "8080"
      "prometheus.io/path"   = "/actuator/prometheus"
    }
  }

  spec {
    selector = {
      app = "payment-service"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }

    # Add health check port
    port {
      name        = "health"
      port        = 8081
      target_port = 8080
      protocol    = "TCP"
    }

    type = "ClusterIP"

    # Session affinity for better performance
    session_affinity = "ClientIP"

    # Publishing not ready addresses
    publish_not_ready_addresses = false
  }
}

# Horizontal Pod Autoscaler
resource "kubernetes_horizontal_pod_autoscaler_v2" "payment_service_hpa" {
  metadata {
    name      = "payment-service-hpa"
    namespace = kubernetes_namespace.payment_service.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.payment_service.metadata[0].name
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
