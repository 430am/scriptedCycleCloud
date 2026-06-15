output "private_ip_address" {
  description = "Private IP of the CycleCloud server NIC."
  value       = azurerm_network_interface.this.private_ip_address
}

output "public_ip_address" {
  description = "Public IP of the VM (null when access_mode != 'public_ip')."
  value       = var.access_mode == "public_ip" ? azurerm_public_ip.vm[0].ip_address : null
}

output "vm_id" {
  description = "Resource ID of the CycleCloud server VM."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the CycleCloud server VM."
  value       = azurerm_linux_virtual_machine.this.name
}

output "vm_principal_id" {
  description = "System-assigned identity principal ID of the VM; used by root for subscription-scope orchestrator role assignment."
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}
