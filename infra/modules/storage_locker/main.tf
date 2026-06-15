resource "azurerm_storage_account" "locker" {
  name                            = "st${var.naming_token_compact}lkr"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
  tags                            = var.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_role_assignment" "caller_blob_owner" {
  scope                = azurerm_storage_account.locker.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = var.caller_object_id
}

resource "time_sleep" "caller_rbac_propagation" {
  depends_on      = [azurerm_role_assignment.caller_blob_owner]
  create_duration = "60s"
}

resource "azurerm_storage_container" "cyclecloud" {
  depends_on = [time_sleep.caller_rbac_propagation]

  name                  = "cyclecloud"
  storage_account_id    = azurerm_storage_account.locker.id
  container_access_type = "private"
}

resource "azurerm_private_endpoint" "locker_blob" {
  name                = "pe-lkr-blob-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-lkr-blob"
    private_connection_resource_id = azurerm_storage_account.locker.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "lkr-blob-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_id_blob]
  }
}

resource "azurerm_monitor_diagnostic_setting" "locker_blob" {
  name                       = "diag-lkr-blob-${var.naming_token}"
  target_resource_id         = "${azurerm_storage_account.locker.id}/blobServices/default"
  log_analytics_workspace_id = var.diagnostic_workspace_id

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
