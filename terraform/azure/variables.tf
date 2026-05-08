variable "azure_location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "aks_cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "proj-devops-aks"
}

variable "dockerhub_username" {
  description = "DockerHub username"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

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
