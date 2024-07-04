variable "subscription_id" {
  description = "The project Azure subscription id"
}

variable "resource_group_name" {
  description = "The project resource group name"
}

variable "databricks_account_id" {
  description = "Azure Databricks account id from Databricks account console"
  type        = string
}

variable "databricks_metastore_id" {
  description = "Azure Databricks metastore id"
  type        = string
}
