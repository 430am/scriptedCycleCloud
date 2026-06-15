data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

data "http" "caller_ip" {
  url = "https://api.ipify.org"
}

resource "random_pet" "naming" {
  length    = 2
  separator = "-"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-cyclecloud-${local.naming_token}"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "./modules/network"

  access_mode         = var.access_mode
  allowed_source_ips  = local.allowed_source_ips
  location            = azurerm_resource_group.this.location
  naming_token        = local.naming_token
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
  vnet_address_space  = var.vnet_address_space
}

module "monitoring" {
  source = "./modules/monitoring"

  location             = azurerm_resource_group.this.location
  log_retention_days   = var.log_retention_days
  naming_token         = local.naming_token
  naming_token_compact = local.naming_token_compact
  pe_subnet_id         = module.network.subnet_ids.private_endpoint
  private_dns_zone_ids = module.network.private_dns_zone_ids
  resource_group_name  = azurerm_resource_group.this.name
  tags                 = local.tags
}

module "identity" {
  source = "./modules/identity"

  allowed_source_ips        = local.allowed_source_ips
  caller_object_id          = data.azurerm_client_config.current.object_id
  diagnostic_workspace_id   = module.monitoring.log_analytics_workspace_id
  location                  = azurerm_resource_group.this.location
  naming_token              = local.naming_token
  naming_token_compact      = local.naming_token_compact
  pe_subnet_id              = module.network.subnet_ids.private_endpoint
  private_dns_zone_id_vault = module.network.private_dns_zone_ids["privatelink.vaultcore.azure.net"]
  resource_group_name       = azurerm_resource_group.this.name
  tags                      = local.tags
}

module "storage_locker" {
  source = "./modules/storage_locker"

  caller_object_id         = data.azurerm_client_config.current.object_id
  diagnostic_workspace_id  = module.monitoring.log_analytics_workspace_id
  location                 = azurerm_resource_group.this.location
  naming_token             = local.naming_token
  naming_token_compact     = local.naming_token_compact
  pe_subnet_id             = module.network.subnet_ids.private_endpoint
  private_dns_zone_id_blob = module.network.private_dns_zone_ids["privatelink.blob.core.windows.net"]
  resource_group_name      = azurerm_resource_group.this.name
  tags                     = local.tags
}

module "cyclecloud_server" {
  source = "./modules/cyclecloud_server"

  access_mode                 = var.access_mode
  admin_username              = var.admin_username
  application_name            = local.naming_token
  diagnostic_workspace_id     = module.monitoring.log_analytics_workspace_id
  install_script_path         = "${path.module}/../scripts/install-cyclecloud.sh.tftpl"
  key_vault_id                = module.identity.key_vault_id
  key_vault_name              = module.identity.key_vault_name
  location                    = azurerm_resource_group.this.location
  locker_container_name       = module.storage_locker.container_name
  locker_storage_account_id   = module.storage_locker.storage_account_id
  locker_storage_account_name = module.storage_locker.storage_account_name
  naming_token                = local.naming_token
  register_script_path        = "${path.module}/../scripts/register-cyclecloud.sh.tftpl"
  resource_group_name         = azurerm_resource_group.this.name
  server_image                = var.server_image
  server_subnet_id            = module.network.subnet_ids.server
  ssh_public_key              = module.identity.ssh_public_key_openssh
  subscription_id             = data.azurerm_subscription.current.subscription_id
  tags                        = local.tags
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  uai_id                      = module.identity.user_assigned_identity_id
  vm_size                     = var.server_vm_size
}

# Custom subscription-scope role used by the CycleCloud server to orchestrate
# cluster nodes. Microsoft.{Compute,Network,Storage,Resources} are required;
# ManagedIdentity/*/assign lets CycleCloud attach the UAI to cluster nodes.
# ponytail: starting from documented superset; tighten once a cluster runs and
# we can lift the actual call list from activity logs.
resource "azurerm_role_definition" "cyclecloud_orchestrator" {
  name        = "CycleCloud Orchestrator (${local.naming_token})"
  scope       = data.azurerm_subscription.current.id
  description = "Permissions required for the CycleCloud server to manage cluster compute resources."

  permissions {
    actions = [
      "Microsoft.Authorization/*/read",
      "Microsoft.Compute/*",
      "Microsoft.ManagedIdentity/userAssignedIdentities/*/read",
      "Microsoft.ManagedIdentity/userAssignedIdentities/*/assign/action",
      "Microsoft.Network/*",
      "Microsoft.Resources/*",
      "Microsoft.Storage/*",
    ]
    not_actions = []
  }

  assignable_scopes = [data.azurerm_subscription.current.id]
}

resource "azurerm_role_assignment" "orchestrator_vm_smi" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = azurerm_role_definition.cyclecloud_orchestrator.role_definition_resource_id
  principal_id       = module.cyclecloud_server.vm_principal_id
}

resource "azurerm_role_assignment" "orchestrator_uai" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = azurerm_role_definition.cyclecloud_orchestrator.role_definition_resource_id
  principal_id       = module.identity.user_assigned_identity_principal_id
}
