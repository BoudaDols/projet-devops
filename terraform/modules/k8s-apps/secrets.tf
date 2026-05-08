resource "kubernetes_secret" "api_gateway" {
  metadata {
    name      = "api-gateway-secret"
    namespace = var.namespace
  }

  data = {
    APP_KEY     = var.app_key
    JWT_SECRET  = var.jwt_secret
    DB_PASSWORD = var.gateway_db_password
  }
}

resource "kubernetes_secret" "abonnement" {
  metadata {
    name      = "abonnement-secrets"
    namespace = var.namespace
  }

  data = {
    DB_USERNAME = "abonnement_user"
    DB_PASSWORD = var.abonnement_db_password
  }
}

resource "kubernetes_secret" "mysql" {
  metadata {
    name      = "mysql-secrets"
    namespace = var.namespace
  }

  data = {
    MYSQL_ROOT_PASSWORD = var.mysql_root_password
    MYSQL_USERNAME      = "abonnement_user"
    MYSQL_PASSWORD      = var.abonnement_db_password
  }
}
