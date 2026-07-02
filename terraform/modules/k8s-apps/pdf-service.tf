# ─────────────────────────────────────────────
# pdf-service configmap
# ─────────────────────────────────────────────
resource "kubernetes_config_map" "pdf_service" {
  metadata {
    name      = "pdf-service-config"
    namespace = var.namespace
  }

  data = {
    DB_HOST         = "pdf-service-mysql"
    DB_PORT         = "3306"
    DB_DATABASE     = "pdf_service"
    DB_USERNAME     = "root"
    REDIS_HOST      = "pdf-service-redis"
    REDIS_PORT      = "6379"
    STORAGE_BACKEND = "s3"
    S3_REGION       = "us-east-1"
    PRESIGNED_URL_TTL = "1800"
  }
}

# ─────────────────────────────────────────────
# pdf-service secret
# ─────────────────────────────────────────────
resource "kubernetes_secret" "pdf_service" {
  metadata {
    name      = "pdf-service-secrets"
    namespace = var.namespace
  }

  data = {
    DB_PASSWORD = var.pdf_service_db_password
  }
}

# ─────────────────────────────────────────────
# pdf-service MySQL
# ─────────────────────────────────────────────
resource "kubernetes_persistent_volume_claim" "pdf_service_mysql" {
  metadata {
    name      = "pdf-service-mysql-pvc"
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

  wait_until_bound = false
}

resource "kubernetes_deployment" "pdf_service_mysql" {
  metadata {
    name      = "pdf-service-mysql"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "pdf-service-mysql"
      }
    }

    template {
      metadata {
        labels = {
          app = "pdf-service-mysql"
        }
      }

      spec {
        container {
          name  = "mysql"
          image = "mysql:8.0"

          port {
            container_port = 3306
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "pdf_service"
          }

          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.pdf_service.metadata[0].name
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
            claim_name = kubernetes_persistent_volume_claim.pdf_service_mysql.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "pdf_service_mysql" {
  metadata {
    name      = "pdf-service-mysql"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "pdf-service-mysql"
    }

    port {
      port        = 3306
      target_port = 3306
    }

    type = "ClusterIP"
  }
}

# ─────────────────────────────────────────────
# pdf-service Redis
# ─────────────────────────────────────────────
resource "kubernetes_deployment" "pdf_service_redis" {
  metadata {
    name      = "pdf-service-redis"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "pdf-service-redis"
      }
    }

    template {
      metadata {
        labels = {
          app = "pdf-service-redis"
        }
      }

      spec {
        container {
          name  = "redis"
          image = "redis:7-alpine"

          port {
            container_port = 6379
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "pdf_service_redis" {
  metadata {
    name      = "pdf-service-redis"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "pdf-service-redis"
    }

    port {
      port        = 6379
      target_port = 6379
    }

    type = "ClusterIP"
  }
}

# ─────────────────────────────────────────────
# pdf-service deployment
# ─────────────────────────────────────────────
resource "kubernetes_deployment" "pdf_service" {
  metadata {
    name      = "pdf-service"
    namespace = var.namespace

    labels = {
      app = "pdf-service"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "pdf-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "pdf-service"
        }
      }

      spec {
        container {
          name  = "pdf-service"
          image = "${var.dockerhub_username}/pdf-service:${var.image_tag}"

          port {
            container_port = 8000
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.pdf_service.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.pdf_service.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment.pdf_service_mysql,
    kubernetes_deployment.pdf_service_redis,
    kubernetes_config_map.pdf_service,
    kubernetes_secret.pdf_service,
  ]

  wait_for_rollout = false
}

resource "kubernetes_service" "pdf_service" {
  metadata {
    name      = "pdf-service"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "pdf-service"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8000
    }

    type = "ClusterIP"
  }
}

# ─────────────────────────────────────────────
# pdf-service network policies
# ─────────────────────────────────────────────
resource "kubernetes_network_policy" "pdf_service" {
  metadata {
    name      = "pdf-service-network-policy"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        app = "pdf-service"
      }
    }

    policy_types = ["Ingress", "Egress"]

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
        port     = "8000"
      }
    }

    egress {
      to {
        pod_selector {
          match_labels = {
            app = "pdf-service-mysql"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = "3306"
      }
    }

    egress {
      to {
        pod_selector {
          match_labels = {
            app = "pdf-service-redis"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = "6379"
      }
    }

    egress {
      ports {
        protocol = "TCP"
        port     = "443"
      }
    }

    egress {
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }
  }
}
