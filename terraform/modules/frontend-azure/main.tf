# ─────────────────────────────────────────────────────────────────────────────
# Frontend static hosting — Azure (Blob Storage + CDN)
# ─────────────────────────────────────────────────────────────────────────────

resource "azurerm_storage_account" "frontend" {
  name                     = replace("${var.project_name}frontend", "-", "")
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  static_website {
    index_document     = "index.html"
    error_404_document = "index.html"
  }
}

resource "azurerm_cdn_profile" "frontend" {
  name                = "${var.project_name}-frontend-cdn"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard_Microsoft"
}

resource "azurerm_cdn_endpoint" "frontend" {
  name                = "${var.project_name}-frontend"
  profile_name        = azurerm_cdn_profile.frontend.name
  location            = var.location
  resource_group_name = var.resource_group_name

  origin {
    name      = "storage"
    host_name = azurerm_storage_account.frontend.primary_blob_host
  }

  origin_host_header = azurerm_storage_account.frontend.primary_blob_host

  is_http_allowed  = false
  is_https_allowed = true
}
