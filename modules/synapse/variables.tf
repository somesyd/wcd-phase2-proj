variable "prefix" {
  description = "Project resource naming prefix"
}

variable "resource_group_name" {
  description = "Project resource group name"
}

variable "depends_on_resource_group" {
  description = "Dependency value to force resource group creation"
}

variable "storage_account_name" {
  description = "Project storage account name"
}

variable "depends_on_storage_account" {
  description = "Dependency value to force storage account creation"
}

variable "internal_key_vault_name" {
  description = "Name of project's internal key vault"
}

variable "depends_on_internal_vault" {
  description = "Internal vault id must be create before resource runs"
}

variable "external_key_vault_resource_group" {
  description = "Name of the resource group for external key vault"
}

variable "external_key_vault_name" {
  description = "Name of the external key vault"
}

variable "admin_login" {
  description = "Azure login name (probably email address)"
}

variable "ip_start_and_finish" {
  description = "IP address to access Synapse Studio"
}