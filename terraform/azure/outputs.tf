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
