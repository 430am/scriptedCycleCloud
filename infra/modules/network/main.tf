locals {
  subnet_specs = merge(
    {
      cluster          = { newbits = 7, netnum = 0 }
      private_endpoint = { newbits = 10, netnum = 8 }
      server           = { newbits = 10, netnum = 9 }
    },
    var.access_mode == "bastion" ? {
      AzureBastionSubnet = { newbits = 10, netnum = 10 }
    } : {}
  )

  subnets = {
    for name, spec in local.subnet_specs :
    name => cidrsubnet(var.vnet_address_space[0], spec.newbits, spec.netnum)
  }

  # Zones required for KV (vault) + locker SA (blob) + monitoring SA (blob+table)
  # + AMPLS (monitor, oms.opinsights, ods.opinsights, agentsvc).
  private_dns_zone_names = toset([
    "privatelink.agentsvc.azure-automation.net",
    "privatelink.blob.core.windows.net",
    "privatelink.monitor.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.table.core.windows.net",
    "privatelink.vaultcore.azure.net",
  ])

  bastion_rules = {
    AllowHttpsInBound = {
      priority                   = 120
      direction                  = "Inbound"
      protocol                   = "Tcp"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
      destination_port_ranges    = ["443"]
    }
    AllowGatewayManagerInBound = {
      priority                   = 130
      direction                  = "Inbound"
      protocol                   = "Tcp"
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
      destination_port_ranges    = ["443"]
    }
    AllowLoadBalancerInBound = {
      priority                   = 140
      direction                  = "Inbound"
      protocol                   = "Tcp"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
      destination_port_ranges    = ["443"]
    }
    AllowBastionHostCommunicationInBound = {
      priority                   = 150
      direction                  = "Inbound"
      protocol                   = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
      destination_port_ranges    = ["8080", "5701"]
    }
    AllowSshRdpOutBound = {
      priority                   = 100
      direction                  = "Outbound"
      protocol                   = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "VirtualNetwork"
      destination_port_ranges    = ["22", "3389"]
    }
    AllowAzureCloudOutBound = {
      priority                   = 110
      direction                  = "Outbound"
      protocol                   = "Tcp"
      source_address_prefix      = "*"
      destination_address_prefix = "AzureCloud"
      destination_port_ranges    = ["443"]
    }
    AllowBastionHostCommunicationOutBound = {
      priority                   = 120
      direction                  = "Outbound"
      protocol                   = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
      destination_port_ranges    = ["8080", "5701"]
    }
    AllowGetSessionInformationOutBound = {
      priority                   = 130
      direction                  = "Outbound"
      protocol                   = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "Internet"
      destination_port_ranges    = ["80", "443"]
    }
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-cc-${var.naming_token}"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value]

  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-cc-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_nat_gateway" "this" {
  name                = "nat-cc-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  for_each = toset(["cluster", "server"])

  subnet_id      = azurerm_subnet.this[each.key].id
  nat_gateway_id = azurerm_nat_gateway.this.id
}

resource "azurerm_network_security_group" "server" {
  name                = "nsg-server-cc-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "server_allow_vnet_https" {
  name                        = "AllowVnetHttpsInbound"
  network_security_group_name = azurerm_network_security_group.server.name
  resource_group_name         = var.resource_group_name
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "VirtualNetwork"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "443"
}

resource "azurerm_network_security_rule" "server_allow_vnet_ssh" {
  name                        = "AllowVnetSshInbound"
  network_security_group_name = azurerm_network_security_group.server.name
  resource_group_name         = var.resource_group_name
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "VirtualNetwork"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
}

resource "azurerm_network_security_rule" "server_allow_operator" {
  count = var.access_mode == "public_ip" && length(var.allowed_source_ips) > 0 ? 1 : 0

  name                        = "AllowOperatorInbound"
  network_security_group_name = azurerm_network_security_group.server.name
  resource_group_name         = var.resource_group_name
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefixes     = var.allowed_source_ips
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = ["22", "443"]
}

resource "azurerm_subnet_network_security_group_association" "server" {
  subnet_id                 = azurerm_subnet.this["server"].id
  network_security_group_id = azurerm_network_security_group.server.id
}

# --- Bastion (only when access_mode = bastion) ---

resource "azurerm_network_security_group" "bastion" {
  count = var.access_mode == "bastion" ? 1 : 0

  name                = "nsg-bastion-cc-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Required rules per https://learn.microsoft.com/azure/bastion/bastion-nsg.
resource "azurerm_network_security_rule" "bastion" {
  for_each = { for k, v in local.bastion_rules : k => v if var.access_mode == "bastion" }

  name                        = each.key
  network_security_group_name = azurerm_network_security_group.bastion[0].name
  resource_group_name         = var.resource_group_name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = "Allow"
  protocol                    = each.value.protocol
  source_address_prefix       = each.value.source_address_prefix
  source_port_range           = "*"
  destination_address_prefix  = each.value.destination_address_prefix
  destination_port_ranges     = each.value.destination_port_ranges
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  count = var.access_mode == "bastion" ? 1 : 0

  subnet_id                 = azurerm_subnet.this["AzureBastionSubnet"].id
  network_security_group_id = azurerm_network_security_group.bastion[0].id
}

resource "azurerm_public_ip" "bastion" {
  count = var.access_mode == "bastion" ? 1 : 0

  name                = "pip-bastion-cc-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  count = var.access_mode == "bastion" ? 1 : 0

  name                = "bas-cc-${var.naming_token}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tunneling_enabled   = true
  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.this["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
  tags = var.tags
}

# --- Private DNS zones (VNet-linked) ---

resource "azurerm_private_dns_zone" "this" {
  for_each = local.private_dns_zone_names

  name                = each.key
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.private_dns_zone_names

  name                  = "vnl-${replace(each.key, ".", "-")}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = var.tags
}
