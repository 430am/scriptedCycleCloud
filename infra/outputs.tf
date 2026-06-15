output "bastion_dns_name" {
  description = "Fully-qualified DNS name of the Bastion host (null when access_mode != 'bastion')."
  value       = module.network.bastion_dns_name
}

output "cyclecloud_server_private_ip" {
  description = "Private IP of the CycleCloud server VM."
  value       = module.cyclecloud_server.private_ip_address
}

output "cyclecloud_server_public_ip" {
  description = "Public IP of the CycleCloud server VM (null when access_mode != 'public_ip')."
  value       = module.cyclecloud_server.public_ip_address
}

output "cyclecloud_server_vm_name" {
  description = "Name of the CycleCloud server VM."
  value       = module.cyclecloud_server.vm_name
}

output "key_vault_uri" {
  description = "Key Vault URI hosting the SSH key pair and CycleCloud admin password."
  value       = module.identity.key_vault_uri
}

output "locker_storage_account_name" {
  description = "Storage account holding the CycleCloud locker container."
  value       = module.storage_locker.storage_account_name
}

output "resource_group_name" {
  description = "Resource group containing every deployed resource."
  value       = azurerm_resource_group.this.name
}
