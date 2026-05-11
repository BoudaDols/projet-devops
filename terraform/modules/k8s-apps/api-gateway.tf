resource "kubernetes_deployment" "api_gateway" {
  metadata {
    name      = "api-gateway"
    namespace = var.namespace

    labels = {
      app = "api-gateway"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "api-gateway"
      }
    }

    template {
      metadata {
        labels = {
          app = "api-gateway"
        }
      }

      spec {
        container {
          name  = "api-gateway"
          image = "${var.dockerhub_username}/api-gateway:${var.image_tag}"

          port {
            container_port = 80
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.api_gateway.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.api_gateway.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/up"
              port = 80
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/up"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment.api_gateway_mysql,
    kubernetes_secret.api_gateway,
    kubernetes_config_map.api_gateway,
  ]

  wait_for_rollout = false
}

resource "kubernetes_service" "api_gateway" {
  metadata {
    name      = "api-gateway-service"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "api-gateway"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
