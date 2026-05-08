resource "kubernetes_deployment" "abonnement" {
  metadata {
    name      = "abonnement"
    namespace = var.namespace

    labels = {
      app = "abonnement"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "abonnement"
      }
    }

    template {
      metadata {
        labels = {
          app = "abonnement"
        }
      }

      spec {
        init_container {
          name    = "migration"
          image   = "${var.dockerhub_username}/abonnement:${var.image_tag}"
          command = ["php", "bin/migrate.php"]

          env_from {
            config_map_ref {
              name = kubernetes_config_map.abonnement.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.abonnement.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.mysql.metadata[0].name
            }
          }
        }

        container {
          name  = "abonnement"
          image = "${var.dockerhub_username}/abonnement:${var.image_tag}"

          port {
            container_port = 8080
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.abonnement.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.abonnement.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
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
    kubernetes_deployment.abonnement_mysql,
    kubernetes_secret.abonnement,
    kubernetes_secret.mysql,
    kubernetes_config_map.abonnement,
  ]
}

resource "kubernetes_service" "abonnement" {
  metadata {
    name      = "abonnement"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "abonnement"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}
