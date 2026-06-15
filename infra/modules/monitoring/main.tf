resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-cc-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_storage_account" "monitoring" {
  name                            = "st${var.naming_token_compact}mon"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  tags                            = var.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_role_assignment" "la_blob_contributor" {
  scope                = azurerm_storage_account.monitoring.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_log_analytics_workspace.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "la_table_contributor" {
  scope                = azurerm_storage_account.monitoring.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_log_analytics_workspace.this.identity[0].principal_id
}

resource "azurerm_log_analytics_linked_storage_account" "custom_logs" {
  data_source_type      = "CustomLogs"
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.this.id
  storage_account_ids   = [azurerm_storage_account.monitoring.id]
}

# --- AMPLS ---

resource "azurerm_monitor_private_link_scope" "this" {
  name                  = "ampls-cc-${var.naming_token}"
  resource_group_name   = var.resource_group_name
  ingestion_access_mode = "PrivateOnly"
  # ponytail: query stays Open so operators can hit Log Analytics from a workstation.
  # Tighten to PrivateOnly once everyone is in-VNet via Bastion / jump host.
  query_access_mode = "Open"
  tags              = var.tags
}

resource "azurerm_monitor_private_link_scoped_service" "workspace" {
  name                = "amplss-workspace"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.this.name
  linked_resource_id  = azurerm_log_analytics_workspace.this.id
}

# --- Private endpoints ---

resource "azurerm_private_endpoint" "monitoring_blob" {
  name                = "pe-mon-blob-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-mon-blob"
    private_connection_resource_id = azurerm_storage_account.monitoring.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "mon-blob-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_ids["privatelink.blob.core.windows.net"]]
  }
}

resource "azurerm_private_endpoint" "monitoring_table" {
  name                = "pe-mon-table-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-mon-table"
    private_connection_resource_id = azurerm_storage_account.monitoring.id
    subresource_names              = ["table"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "mon-table-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_ids["privatelink.table.core.windows.net"]]
  }
}

resource "azurerm_private_endpoint" "ampls" {
  name                = "pe-ampls-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-ampls"
    private_connection_resource_id = azurerm_monitor_private_link_scope.this.id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "ampls-zone-group"
    private_dns_zone_ids = [
      var.private_dns_zone_ids["privatelink.agentsvc.azure-automation.net"],
      var.private_dns_zone_ids["privatelink.blob.core.windows.net"],
      var.private_dns_zone_ids["privatelink.monitor.azure.com"],
      var.private_dns_zone_ids["privatelink.ods.opinsights.azure.com"],
      var.private_dns_zone_ids["privatelink.oms.opinsights.azure.com"],
    ]
  }
}

# --- Diagnostic settings on the monitoring SA itself ---

resource "azurerm_monitor_diagnostic_setting" "monitoring_blob" {
  name                       = "diag-mon-blob-${var.naming_token}"
  target_resource_id         = "${azurerm_storage_account.monitoring.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "monitoring_table" {
  name                       = "diag-mon-table-${var.naming_token}"
  target_resource_id         = "${azurerm_storage_account.monitoring.id}/tableServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}
