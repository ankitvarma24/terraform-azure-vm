provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "av_devops_rg"
  location = "East US"
}

module "network" {
  source   = "../../modules/network"
  rg_name  = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
}