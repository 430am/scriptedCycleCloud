output "key_vault_id" {
  description = "Resource ID of the Key Vault."
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "Name of the Key Vault. Used by VM scripts that call `az keyvault` with --vault-name."
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "DNS URI of the Key Vault."
  value       = azurerm_key_vault.this.vault_uri
}

output "secret_ids" {
  description = "Map of secret name -> versionless secret ID. Use this when scripts on the VM need to fetch by name."
  value = {
    "cyclecloud-admin-password"  = azurerm_key_vault_secret.admin_password.versionless_id
    "cyclecloud-ssh-public-key"  = azurerm_key_vault_secret.ssh_public_key.versionless_id
    "cyclecloud-ssh-private-key" = azurerm_key_vault_secret.ssh_private_key.versionless_id
  }
}

output "ssh_public_key_openssh" {
  description = "Public SSH key in OpenSSH format for injection into VM admin_ssh_key."
  value       = tls_private_key.ssh.public_key_openssh
}

output "user_assigned_identity_id" {
  description = "Resource ID of the user-assigned identity attached to the CycleCloud server and cluster nodes."
  value       = azurerm_user_assigned_identity.cluster_nodes.id
}

output "user_assigned_identity_principal_id" {
  description = "Principal (object) ID of the user-assigned identity, for role assignments."
  value       = azurerm_user_assigned_identity.cluster_nodes.principal_id
}
