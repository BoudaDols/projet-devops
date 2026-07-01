output "storage_account_name" {
  description = "Azure Storage Account name for frontend deployment"
  value       = azurerm_storage_account.frontend.name
}

output "blob_container" {
  description = "Azure Blob container name for static website"
  value       = "$web"
}

output "frontend_url" {
  description = "Frontend URL on Azure CDN"
  value       = "https://${azurerm_cdn_endpoint.frontend.fqdn}"
}
