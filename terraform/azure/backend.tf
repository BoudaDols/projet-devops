terraform {
  backend "azurerm" {
    resource_group_name  = "proj-devops-tfstate-rg"
    storage_account_name = "projdevopstfstate"
    container_name       = "tfstate"
    key                  = "azure/terraform.tfstate"
  }
}
