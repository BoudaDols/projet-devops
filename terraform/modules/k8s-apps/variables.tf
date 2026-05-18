variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "default"
}

variable "dockerhub_username" {
  description = "DockerHub username for image references"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "storage_class" {
  description = "Kubernetes storage class for PVCs"
  type        = string
}

# api-gateway secrets
variable "app_key" {
  description = "Laravel APP_KEY"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret"
  type        = string
  sensitive   = true
}

variable "gateway_db_password" {
  description = "api-gateway MySQL root password"
  type        = string
  sensitive   = true
}

# abonnement secrets
variable "abonnement_db_password" {
  description = "abonnement MySQL user password"
  type        = string
  sensitive   = true
}

variable "mysql_root_password" {
  description = "abonnement MySQL root password"
  type        = string
  sensitive   = true
}

# user-service secrets
variable "user_service_db_password" {
  description = "user-service MySQL root password"
  type        = string
  sensitive   = true
}

# notification-service secrets
variable "smtp_user" {
  description = "Mailtrap SMTP username"
  type        = string
  sensitive   = true
}

variable "smtp_pass" {
  description = "Mailtrap SMTP password"
  type        = string
  sensitive   = true
}

variable "default_recipient" {
  description = "Fallback email recipient when user_email is absent from Kafka event"
  type        = string
  sensitive   = true
}
