resource "kubernetes_network_policy" "abonnement" {
  metadata {
    name      = "abonnement-network-policy"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        app = "abonnement"
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

resource "kubernetes_network_policy" "abonnement_mysql" {
  metadata {
    name      = "mysql-network-policy"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        app = "mysql"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "abonnement"
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
