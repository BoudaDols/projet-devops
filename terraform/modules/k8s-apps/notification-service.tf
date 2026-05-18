# ─────────────────────────────────────────────
# notification-service configmap
# ─────────────────────────────────────────────
resource "kubernetes_config_map" "notification_service" {
  metadata {
    name      = "notification-config"
    namespace = var.namespace
  }

  data = {
    KAFKA_BROKERS = "kafka.${var.namespace}.svc.cluster.local:9092"
    KAFKA_ENABLED = "true"
    SMTP_HOST     = "sandbox.smtp.mailtrap.io"
    SMTP_PORT     = "2525"
    MAIL_FROM     = "noreply@abonnement.local"
  }
}

# ─────────────────────────────────────────────
# notification-service secret
# ─────────────────────────────────────────────
resource "kubernetes_secret" "notification_service" {
  metadata {
    name      = "notification-secrets"
    namespace = var.namespace
  }

  data = {
    SMTP_USER          = var.smtp_user
    SMTP_PASS          = var.smtp_pass
    DEFAULT_RECIPIENT  = var.default_recipient
  }
}

# ─────────────────────────────────────────────
# notification-service deployment
# ─────────────────────────────────────────────
resource "kubernetes_deployment" "notification_service" {
  metadata {
    name      = "notification-service"
    namespace = var.namespace

    labels = {
      app = "notification-service"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "notification-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "notification-service"
        }
      }

      spec {
        container {
          name  = "notification-service"
          image = "${var.dockerhub_username}/notification-service:${var.image_tag}"

          port {
            container_port = 5000
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.notification_service.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.notification_service.metadata[0].name
            }
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

          liveness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment.kafka,
    kubernetes_config_map.notification_service,
    kubernetes_secret.notification_service,
  ]

  wait_for_rollout = false
}

# ─────────────────────────────────────────────
# notification-service service (health probe only)
# ─────────────────────────────────────────────
resource "kubernetes_service" "notification_service" {
  metadata {
    name      = "notification-service"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "notification-service"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 5000
    }

    type = "ClusterIP"
  }
}

# ─────────────────────────────────────────────
# notification-service network policy
# Egress only: Kafka (9092) + SMTP (2525/587/465) + DNS (53)
# No ingress from other services
# ─────────────────────────────────────────────
resource "kubernetes_network_policy" "notification_service" {
  metadata {
    name      = "notification-service-network-policy"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        app = "notification-service"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Allow health probe checks on port 5000
    ingress {
      ports {
        protocol = "TCP"
        port     = "5000"
      }
    }

    # Allow egress to Kafka
    egress {
      to {
        pod_selector {
          match_labels = {
            app = "kafka"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = "9092"
      }
    }

    # Allow egress to external SMTP
    egress {
      ports {
        protocol = "TCP"
        port     = "2525"
      }
    }

    egress {
      ports {
        protocol = "TCP"
        port     = "587"
      }
    }

    egress {
      ports {
        protocol = "TCP"
        port     = "465"
      }
    }

    # Allow DNS resolution
    egress {
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }
  }
}
