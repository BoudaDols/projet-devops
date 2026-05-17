terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ─────────────────────────────────────────────
# Resource Group
# ─────────────────────────────────────────────
resource "azurerm_resource_group" "this" {
  name     = "proj-devops-rg"
  location = var.azure_location
}

# ─────────────────────────────────────────────
# VNet
# ─────────────────────────────────────────────
resource "azurerm_virtual_network" "this" {
  name                = "proj-devops-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.1.1.0/24"]
}

# ─────────────────────────────────────────────
# AKS Cluster
# ─────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "this" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.aks_cluster_name

  # system node pool — regular VM for stable stateful workloads (MySQL)
  default_node_pool {
    name           = "system"
    node_count     = 1
    vm_size        = "Standard_B2s" # cheapest viable size
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure" # enables network policies
  }
}

# spot node pool — for app pods (api-gateway, abonnement)
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = "Standard_B2s"
  node_count            = 1
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = -1 # use current spot price

  node_labels = {
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }

  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]
}

# ─────────────────────────────────────────────
# Kubernetes provider — uses AKS cluster
# ─────────────────────────────────────────────
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.this.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
}

# ─────────────────────────────────────────────
# k8s-apps module
# ─────────────────────────────────────────────
module "k8s_apps" {
  source = "../modules/k8s-apps"

  namespace          = "default"
  dockerhub_username = var.dockerhub_username
  image_tag          = var.image_tag
  storage_class      = "managed-premium"

  app_key                = var.app_key
  jwt_secret             = var.jwt_secret
  gateway_db_password    = var.gateway_db_password
  abonnement_db_password = var.abonnement_db_password
  mysql_root_password    = var.mysql_root_password
  user_service_db_password = var.user_service_db_password

  depends_on = [azurerm_kubernetes_cluster.this]
}
