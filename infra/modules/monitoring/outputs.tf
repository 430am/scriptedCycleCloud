output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace; pass into other modules' diagnostic settings."
  value       = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.name
}

output "monitoring_storage_account_id" {
  description = "Resource ID of the monitoring storage account."
  value       = azurerm_storage_account.monitoring.id
}

output "monitoring_storage_account_name" {
  description = "Name of the monitoring storage account."
  value       = azurerm_storage_account.monitoring.name
}
