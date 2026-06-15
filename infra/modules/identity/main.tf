resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}
# ponytail: regular (not ephemeral) so public_key_openssh can flow into the VM's
# admin_ssh_key block without juggling write-only arguments. Private key ends
# up in BOTH state and Key Vault. Upgrade path when needed: ephemeral
# tls_private_key + azurerm_key_vault_secret.value_wo, and feed the VM via a
# data.azurerm_key_vault_secret lookup on the public-key secret.

resource "random_password" "admin" {
  length      = 20
  special     = true
  min_lower   = 2
  min_upper   = 2
  min_numeric = 2
  min_special = 2
}

resource "azurerm_key_vault" "this" {
  name                          = "kvcc${var.naming_token_compact}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
  public_network_access_enabled = true
  tags                          = var.tags

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = var.allowed_source_ips
  }
}

resource "azurerm_role_assignment" "caller_kv_admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.caller_object_id
}

resource "time_sleep" "kv_rbac_propagation" {
  depends_on      = [azurerm_role_assignment.caller_kv_admin]
  create_duration = "60s"
}

resource "azurerm_key_vault_secret" "admin_password" {
  depends_on = [time_sleep.kv_rbac_propagation]

  name         = "cyclecloud-admin-password"
  value        = random_password.admin.result
  key_vault_id = azurerm_key_vault.this.id
}

resource "azurerm_key_vault_secret" "ssh_public_key" {
  depends_on = [time_sleep.kv_rbac_propagation]

  name         = "cyclecloud-ssh-public-key"
  value        = tls_private_key.ssh.public_key_openssh
  key_vault_id = azurerm_key_vault.this.id
}

resource "azurerm_key_vault_secret" "ssh_private_key" {
  depends_on = [time_sleep.kv_rbac_propagation]

  name         = "cyclecloud-ssh-private-key"
  value        = tls_private_key.ssh.private_key_openssh
  key_vault_id = azurerm_key_vault.this.id
  content_type = "application/x-openssh-key"
}

resource "azurerm_user_assigned_identity" "cluster_nodes" {
  name                = "uai-cc-nodes-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv-cc-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_id_vault]
  }
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diag-kv-${var.naming_token}"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.diagnostic_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

data "azurerm_client_config" "current" {}
