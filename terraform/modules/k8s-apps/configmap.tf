resource "kubernetes_config_map" "api_gateway" {
  metadata {
    name      = "api-gateway-config"
    namespace = var.namespace
  }

  data = {
    APP_NAME                = "API Gateway"
    APP_ENV                 = "production"
    APP_DEBUG               = "false"
    APP_URL                 = "http://localhost"
    DB_CONNECTION           = "mysql"
    DB_HOST                 = "api-gateway-mysql-service"
    DB_PORT                 = "3306"
    DB_DATABASE             = "api_gateway"
    DB_USERNAME             = "root"
    JWT_TTL                 = "60"
    JWT_REFRESH_TTL         = "20160"
    CORS_ALLOWED_ORIGINS    = "*"
    GATEWAY_TIMEOUT         = "10"
    SERVICE_ABONNEMENT_URL  = "http://abonnement.${var.namespace}.svc.cluster.local/api"
    SERVICE_USER_URL        = "http://user-service.${var.namespace}.svc.cluster.local/api"
    SMS_DRIVER              = "log"
    LOG_CHANNEL             = "stdout"
    CACHE_STORE             = "redis"
    SESSION_DRIVER          = "redis"
    QUEUE_CONNECTION        = "redis"
    REDIS_CLIENT            = "predis"
    REDIS_HOST              = "redis.${var.namespace}.svc.cluster.local"
    REDIS_PORT              = "6379"
    KAFKA_BROKERS           = "kafka.${var.namespace}.svc.cluster.local:9092"
    KAFKA_ENABLED           = "true"
  }
}

resource "kubernetes_config_map" "abonnement" {
  metadata {
    name      = "abonnement-config"
    namespace = var.namespace
  }

  data = {
    APP_ENV         = "prod"
    APP_DEBUG       = "false"
    DB_CONNECTION   = "mysql"
    DB_HOST         = "mysql"
    DB_PORT         = "3306"
    DB_DATABASE     = "abonnement"
    PAYMENT_GATEWAY = "stripe"
    KAFKA_BROKERS   = "kafka.${var.namespace}.svc.cluster.local:9092"
    KAFKA_ENABLED   = "true"
  }
}
