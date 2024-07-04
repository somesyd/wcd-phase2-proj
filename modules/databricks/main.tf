terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.109.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "1.48.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "databricks" {
  alias = "workspace"
  host  = azurerm_databricks_workspace.proj-db-ws.workspace_url
}

provider "databricks" {
  alias      = "accounts"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
}

data "azurerm_subscription" "this" {
  subscription_id = var.subscription_id
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {
}

resource "azurerm_databricks_workspace" "proj-db-ws" {
  name                = "proj-phase2-databricks"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  sku                 = "premium"
}

resource "databricks_metastore_assignment" "this" {
  provider     = databricks.workspace
  workspace_id = azurerm_databricks_workspace.proj-db-ws.workspace_id
  metastore_id = var.databricks_metastore_id
}

resource "azurerm_databricks_access_connector" "ext_access_connector" {
  name                = "databricks-access-connector"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  identity {
    type = "SystemAssigned"
  }
}

