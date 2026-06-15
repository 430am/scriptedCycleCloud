output "container_name" {
  description = "Name of the CycleCloud locker container."
  value       = azurerm_storage_container.cyclecloud.name
}

output "storage_account_id" {
  description = "Resource ID of the locker storage account."
  value       = azurerm_storage_account.locker.id
}

output "storage_account_name" {
  description = "Name of the locker storage account; used as the CycleCloud locker name when registering the subscription."
  value       = azurerm_storage_account.locker.name
}
