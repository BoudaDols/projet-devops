output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.this.name
}

output "aks_cluster_endpoint" {
  description = "AKS cluster endpoint"
  value       = azurerm_kubernetes_cluster.this.kube_config[0].host
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.this.name
}

output "frontend_storage_account" {
  description = "Azure Storage Account name for frontend deployment"
  value       = module.frontend.azure_storage_account_name
}

output "frontend_url" {
  description = "Frontend URL on Azure CDN (update CORS_ALLOWED_ORIGINS in api-gateway configmap with this)"
  value       = module.frontend.frontend_url_azure
}
