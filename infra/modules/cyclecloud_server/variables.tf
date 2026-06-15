variable "access_mode" {
  type        = string
  description = "'bastion' or 'public_ip'. Drives whether a public IP is attached to the VM NIC."
}

variable "admin_username" {
  type        = string
  description = "Linux admin user created on the VM."
}

variable "application_name" {
  type        = string
  description = "Logical name registered into CycleCloud via `cyclecloud initialize --name`."
}

variable "diagnostic_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID for VM diagnostic settings."
}

variable "install_script_path" {
  type        = string
  description = "Path to the install script template (rendered with templatefile()) for phase 1."
}

variable "key_vault_id" {
  type        = string
  description = "Resource ID of the Key Vault. Used as the RBAC scope for the VM SMI's Key Vault Secrets User assignment."
}

variable "key_vault_name" {
  type        = string
  description = "Name of the Key Vault. Passed into the register script for `az keyvault --vault-name` calls."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "locker_container_name" {
  type        = string
  description = "Name of the CycleCloud locker container."
}

variable "locker_storage_account_id" {
  type        = string
  description = "Resource ID of the locker storage account. Used as the RBAC scope for the VM SMI's Storage Blob Data Contributor assignment."
}

variable "locker_storage_account_name" {
  type        = string
  description = "Name of the locker storage account. Passed into the register script as the CycleCloud default locker."
}

variable "naming_token" {
  type        = string
  description = "Naming suffix for module-scoped resources."
}

variable "register_script_path" {
  type        = string
  description = "Path to the register script template (rendered with templatefile()) for phase 2."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group hosting the VM, NIC, and (optional) public IP."
}

variable "server_image" {
  type = object({
    source = string
    marketplace = optional(object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    }))
    shared_image_gallery_image_id = optional(string)
  })
  description = "Image for the CycleCloud server VM. Mirror of the root server_image variable."
}

variable "server_subnet_id" {
  type        = string
  description = "Subnet ID hosting the CycleCloud server VM NIC."
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key in OpenSSH format injected into the VM admin user."
}

variable "subscription_id" {
  type        = string
  description = "Subscription ID registered with CycleCloud via `cyclecloud account create`."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}

variable "tenant_id" {
  type        = string
  description = "Tenant ID registered with CycleCloud via `cyclecloud account create`."
}

variable "uai_id" {
  type        = string
  description = "User-assigned identity resource ID attached to the VM (also used for cluster nodes)."
}

variable "vm_size" {
  type        = string
  description = "VM size for the CycleCloud server."
}
