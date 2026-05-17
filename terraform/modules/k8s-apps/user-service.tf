# ─────────────────────────────────────────────
# user-service secret
# ─────────────────────────────────────────────
resource "kubernetes_secret" "user_service" {
  metadata {
    name      = "user-service-secret"
    namespace = var.namespace
  }

  data = {
    DB_PASSWORD = var.user_service_db_password
  }
}

# ─────────────────────────────────────────────
# user-service configmap
# ─────────────────────────────────────────────
resource "kubernetes_config_map" "user_service" {
  metadata {
    name      = "user-service-config"
    namespace = var.namespace
  }

  data = {
    APP_PORT     = "8080"
    APP_ENV      = "production"
    DB_HOST      = "user-service-mysql"
    DB_PORT      = "3306"
    DB_DATABASE  = "user_service"
    DB_USERNAME  = "root"
    KAFKA_BROKER = "kafka.${var.namespace}.svc.cluster.local:9092"
  }
}

# ─────────────────────────────────────────────
# user-service MySQL
# ─────────────────────────────────────────────
resource "kubernetes_persistent_volume_claim" "user_service_mysql" {
  metadata {
    name      = "user-service-mysql-pvc"
    namespace = var.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "user_service_mysql" {
  metadata {
    name      = "user-service-mysql"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "user-service-mysql"
      }
    }

    template {
      metadata {
        labels = {
          app = "user-service-mysql"
        }
      }

      spec {
        container {
          name  = "user-service-mysql"
          image = "mysql:8.0"

          port {
            container_port = 3306
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "user_service"
          }

          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.user_service.metadata[0].name
                key  = "DB_PASSWORD"
              }
            }
          }

          volume_mount {
            name       = "mysql-data"
            mount_path = "/var/lib/mysql"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "512Mi"
            }
          }
        }

        volume {
          name = "mysql-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.user_service_mysql.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "user_service_mysql" {
  metadata {
    name      = "user-service-mysql"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "user-service-mysql"
    }

    port {
      port        = 3306
      target_port = 3306
    }

    type = "ClusterIP"
  }
}

# ─────────────────────────────────────────────
# user-service deployment
# ─────────────────────────────────────────────
resource "kubernetes_deployment" "user_service" {
  metadata {
    name      = "user-service"
    namespace = var.namespace

    labels = {
      app = "user-service"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "user-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "user-service"
        }
      }

      spec {
        container {
          name  = "user-service"
          image = "${var.dockerhub_username}/user-service:${var.image_tag}"

          port {
            container_port = 8080
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.user_service.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.user_service.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment.user_service_mysql,
    kubernetes_deployment.kafka,
    kubernetes_secret.user_service,
    kubernetes_config_map.user_service,
  ]
}

resource "kubernetes_service" "user_service" {
  metadata {
    name      = "user-service"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "user-service"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

# ─────────────────────────────────────────────
# user-service network policies
# ─────────────────────────────────────────────
resource "kubernetes_network_policy" "user_service" {
  metadata {
    name      = "user-service-network-policy"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        app = "user-service"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "api-gateway"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "8080"
      }
    }
  }
}

resource "kubernetes_network_policy" "user_service_mysql" {
  metadata {
    name      = "user-service-mysql-network-policy"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        app = "user-service-mysql"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "user-service"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "3306"
      }
    }
  }
}
