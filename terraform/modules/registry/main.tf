# ─────────────────────────────────────────────
# AWS ECR
# ─────────────────────────────────────────────
resource "aws_ecr_repository" "this" {
  count = var.cloud == "aws" ? 1 : 0

  name                 = var.name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ─────────────────────────────────────────────
# Azure ACR
# ─────────────────────────────────────────────
resource "azurerm_container_registry" "this" {
  count = var.cloud == "azure" ? 1 : 0

  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
}

output "registry_url" {
  value = var.cloud == "aws" ? (
    length(aws_ecr_repository.this) > 0 ? aws_ecr_repository.this[0].repository_url : ""
    ) : (
    length(azurerm_container_registry.this) > 0 ? azurerm_container_registry.this[0].login_server : ""
  )
}
