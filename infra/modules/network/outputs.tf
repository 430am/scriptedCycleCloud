output "bastion_dns_name" {
  description = "Bastion DNS name when access_mode = 'bastion', otherwise null."
  value       = var.access_mode == "bastion" ? azurerm_bastion_host.this[0].dns_name : null
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone name -> resource ID."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.id }
}

output "subnet_ids" {
  description = "Map of subnet name -> resource ID."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

output "vnet_id" {
  description = "ID of the deployed virtual network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the deployed virtual network."
  value       = azurerm_virtual_network.this.name
}
