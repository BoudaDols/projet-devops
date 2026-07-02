resource "kubernetes_persistent_volume_claim" "kafka" {
  metadata {
    name      = "kafka-pvc"
    namespace = var.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }

  wait_until_bound = false
}

resource "kubernetes_deployment" "kafka" {
  metadata {
    name      = "kafka"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "kafka"
      }
    }

    template {
      metadata {
        labels = {
          app = "kafka"
        }
      }

      spec {
        security_context {
          fs_group = 1000  # Kafka runs as appuser (uid 1000) — EBS volume needs matching ownership
        }

        container {
          name  = "kafka"
          image = "apache/kafka:3.7.0"

          port {
            container_port = 9092
          }

          env {
            name  = "KAFKA_NODE_ID"
            value = "1"
          }
          env {
            name  = "KAFKA_PROCESS_ROLES"
            value = "broker,controller"
          }
          env {
            name  = "KAFKA_CONTROLLER_QUORUM_VOTERS"
            value = "1@localhost:9093"
          }
          env {
            name  = "KAFKA_LISTENERS"
            value = "PLAINTEXT://:9092,CONTROLLER://:9093"
          }
          env {
            name  = "KAFKA_ADVERTISED_LISTENERS"
            value = "PLAINTEXT://kafka.${var.namespace}.svc.cluster.local:9092"
          }
          env {
            name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT"
          }
          env {
            name  = "KAFKA_CONTROLLER_LISTENER_NAMES"
            value = "CONTROLLER"
          }
          env {
            name  = "KAFKA_INTER_BROKER_LISTENER_NAME"
            value = "PLAINTEXT"
          }
          env {
            name  = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR"
            value = "1"
          }
          env {
            name  = "KAFKA_AUTO_CREATE_TOPICS_ENABLE"
            value = "true"
          }
          env {
            name  = "KAFKA_LOG_DIRS"
            value = "/var/lib/kafka/data/kraft-logs"
          }
          env {
            name  = "KAFKA_HEAP_OPTS"
            value = "-Xmx512M -Xms256M"
          }

          volume_mount {
            name       = "kafka-data"
            mount_path = "/var/lib/kafka/data"
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }

          liveness_probe {
            tcp_socket {
              port = 9092
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            tcp_socket {
              port = 9092
            }
            initial_delay_seconds = 20
            period_seconds        = 5
          }
        }

        volume {
          name = "kafka-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.kafka.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "kafka" {
  metadata {
    name      = "kafka"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "kafka"
    }

    port {
      port        = 9092
      target_port = 9092
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_network_policy" "kafka" {
  metadata {
    name      = "kafka-network-policy"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        app = "kafka"
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
      from {
        pod_selector {
          match_labels = {
            app = "abonnement"
          }
        }
      }
      from {
        pod_selector {
          match_labels = {
            app = "user-service"
          }
        }
      }
      from {
        pod_selector {
          match_labels = {
            app = "notification-service"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "9092"
      }
    }
  }
}
