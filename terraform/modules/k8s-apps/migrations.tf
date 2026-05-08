resource "kubernetes_job" "api_gateway_migrations" {
  metadata {
    name      = "api-gateway-migrations"
    namespace = var.namespace
  }

  spec {
    template {
      metadata {}

      spec {
        restart_policy = "Never"

        container {
          name    = "migrations"
          image   = "${var.dockerhub_username}/api-gateway:${var.image_tag}"
          command = ["php", "artisan", "migrate", "--force"]

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
        }
      }
    }

    backoff_limit = 3
  }

  depends_on = [
    kubernetes_deployment.api_gateway_mysql,
  ]

  wait_for_completion = true

  timeouts {
    create = "5m"
  }
}
