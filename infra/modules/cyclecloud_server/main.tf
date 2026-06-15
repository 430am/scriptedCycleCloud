locals {
  install_script = templatefile(var.install_script_path, {})

  register_script = templatefile(var.register_script_path, {
    admin_username        = var.admin_username
    application_name      = var.application_name
    kv_name               = var.key_vault_name
    location              = var.location
    locker_container_name = var.locker_container_name
    locker_sa_name        = var.locker_storage_account_name
    subscription_id       = var.subscription_id
    tenant_id             = var.tenant_id
  })
}

resource "azurerm_public_ip" "vm" {
  count = var.access_mode == "public_ip" ? 1 : 0

  name                = "pip-vm-cc-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_network_interface" "this" {
  name                = "nic-cc-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = var.server_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.access_mode == "public_ip" ? azurerm_public_ip.vm[0].id : null
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                       = "vm-cc-${var.naming_token}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  size                       = var.vm_size
  admin_username             = var.admin_username
  network_interface_ids      = [azurerm_network_interface.this.id]
  encryption_at_host_enabled = true
  tags                       = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [var.uai_id]
  }

  os_disk {
    name                 = "osdisk-cc-${var.naming_token}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_id = var.server_image.source == "shared_image_gallery" ? var.server_image.shared_image_gallery_image_id : null

  dynamic "source_image_reference" {
    for_each = var.server_image.source == "marketplace" ? [var.server_image.marketplace] : []
    content {
      publisher = source_image_reference.value.publisher
      offer     = source_image_reference.value.offer
      sku       = source_image_reference.value.sku
      version   = source_image_reference.value.version
    }
  }

  boot_diagnostics {}
}

resource "azurerm_virtual_machine_extension" "azure_monitor_agent" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.this.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.30"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  tags                       = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "vm" {
  name                       = "diag-vm-${var.naming_token}"
  target_resource_id         = azurerm_linux_virtual_machine.this.id
  log_analytics_workspace_id = var.diagnostic_workspace_id

  enabled_metric {
    category = "AllMetrics"
  }
}

# --- RBAC the VM SMI needs at bootstrap time. Kept inside this module so the
#     register Run Command can depend on a single time_sleep that gates both. ---

resource "azurerm_role_assignment" "vm_smi_kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "vm_smi_locker_blob_contributor" {
  scope                = var.locker_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.this.identity[0].principal_id
}

resource "time_sleep" "vm_smi_rbac_propagation" {
  depends_on = [
    azurerm_role_assignment.vm_smi_kv_secrets_user,
    azurerm_role_assignment.vm_smi_locker_blob_contributor,
  ]
  create_duration = "120s"
}

# --- Bootstrap: two Run Commands. Editing the script template updates the
#     source.script value, which triggers a re-run of that phase automatically. ---

resource "azurerm_virtual_machine_run_command" "install" {
  depends_on = [azurerm_virtual_machine_extension.azure_monitor_agent]

  name               = "install-cyclecloud"
  location           = var.location
  virtual_machine_id = azurerm_linux_virtual_machine.this.id

  source {
    script = local.install_script
  }
}

resource "azurerm_virtual_machine_run_command" "register" {
  depends_on = [
    azurerm_virtual_machine_run_command.install,
    time_sleep.vm_smi_rbac_propagation,
  ]

  name               = "register-cyclecloud"
  location           = var.location
  virtual_machine_id = azurerm_linux_virtual_machine.this.id

  source {
    script = local.register_script
  }
}
