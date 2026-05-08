# ─────────────────────────────────────────────
# api-gateway MySQL
# ─────────────────────────────────────────────
resource "kubernetes_persistent_volume_claim" "api_gateway_mysql" {
  metadata {
    name      = "api-gateway-mysql-pvc"
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

resource "kubernetes_deployment" "api_gateway_mysql" {
  metadata {
    name      = "api-gateway-mysql"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "api-gateway-mysql"
      }
    }

    template {
      metadata {
        labels = {
          app = "api-gateway-mysql"
        }
      }

      spec {
        container {
          name  = "api-gateway-mysql"
          image = "mysql:8.0"

          port {
            container_port = 3306
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "api_gateway"
          }

          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.api_gateway.metadata[0].name
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
            claim_name = kubernetes_persistent_volume_claim.api_gateway_mysql.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "api_gateway_mysql" {
  metadata {
    name      = "api-gateway-mysql-service"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "api-gateway-mysql"
    }

    port {
      port        = 3306
      target_port = 3306
    }

    type = "ClusterIP"
  }
}

# ─────────────────────────────────────────────
# abonnement MySQL
# ─────────────────────────────────────────────
resource "kubernetes_persistent_volume_claim" "abonnement_mysql" {
  metadata {
    name      = "mysql-pvc"
    namespace = var.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "abonnement_mysql" {
  metadata {
    name      = "mysql"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mysql"
      }
    }

    template {
      metadata {
        labels = {
          app = "mysql"
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
            value = "abonnement"
          }

          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql.metadata[0].name
                key  = "MYSQL_ROOT_PASSWORD"
              }
            }
          }

          env {
            name = "MYSQL_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql.metadata[0].name
                key  = "MYSQL_USERNAME"
              }
            }
          }

          env {
            name = "MYSQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql.metadata[0].name
                key  = "MYSQL_PASSWORD"
              }
            }
          }

          volume_mount {
            name       = "mysql-storage"
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
          name = "mysql-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.abonnement_mysql.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "abonnement_mysql" {
  metadata {
    name      = "mysql"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "mysql"
    }

    port {
      port        = 3306
      target_port = 3306
    }

    type = "ClusterIP"
  }
}
