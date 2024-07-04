output "storage_account_id" {
  value = azurerm_storage_account.proj-sa.id
}

output "storage_account_dfs_endpoint" {
  value = azurerm_storage_account.proj-sa.primary_dfs_endpoint
}

output "storage_container_name" {
  value = azurerm_storage_data_lake_gen2_filesystem.raw-fs.name
}