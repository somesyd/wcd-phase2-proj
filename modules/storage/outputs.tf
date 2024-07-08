output "storage_account_id" {
  value = azurerm_storage_account.proj-sa.id
}

output "storage_account_dfs_endpoint" {
  value = azurerm_storage_account.proj-sa.primary_dfs_endpoint
}

output "storage_account_name" {
  value = azurerm_storage_account.proj-sa.name
}

output "storage_container_layer1_name" {
  value = azurerm_storage_data_lake_gen2_filesystem.raw-fs.name
}

output "storage_container_layer2_name" {
  value = azurerm_storage_data_lake_gen2_filesystem.secondary-fs.name
}
output "storage_container_layer3_name" {
  value = azurerm_storage_data_lake_gen2_filesystem.third-fs.name
}

output "storage_container_meta_name" {
  value = azurerm_storage_data_lake_gen2_filesystem.meta.name
}