variable "access_mode" {
  type        = string
  description = "How operators reach the CycleCloud server. 'bastion' deploys Azure Bastion and no public IP on the VM; 'public_ip' attaches a public IP and uses allowed_ip_addresses for NSG allow-list."
  default     = "bastion"

  validation {
    condition     = contains(["bastion", "public_ip"], var.access_mode)
    error_message = "access_mode must be one of: bastion, public_ip."
  }
}

variable "admin_username" {
  type        = string
  description = "Linux admin user created on the CycleCloud server VM."
  default     = "azureuser"
}

variable "allowed_ip_addresses" {
  type        = list(string)
  description = "Operator source IPs (CIDR form) allowed to reach the CycleCloud server when access_mode = 'public_ip'. Also added to Key Vault firewall."
  default     = []
}

variable "application_name" {
  type        = string
  description = "Short name fragment baked into every resource name. Empty value falls back to a random_pet token."
  default     = ""

  validation {
    condition     = var.application_name == "" || can(regex("^[a-z0-9-]{1,12}$", var.application_name))
    error_message = "application_name must be empty or 1-12 chars matching [a-z0-9-]."
  }
}

variable "location" {
  type        = string
  description = "Azure region for every resource."
  default     = "eastus2"
}

variable "log_retention_days" {
  type        = number
  description = "Retention applied to the Log Analytics workspace and all diagnostic settings."
  default     = 30
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
  description = "CycleCloud server VM image. 'source' must be 'marketplace' or 'shared_image_gallery'; the matching nested attribute is required."
  default = {
    source = "marketplace"
    marketplace = {
      publisher = "Canonical"
      offer     = "ubuntu-24_04-lts"
      sku       = "server"
      version   = "latest"
    }
  }

  validation {
    condition = (
      (var.server_image.source == "marketplace" && var.server_image.marketplace != null && var.server_image.shared_image_gallery_image_id == null) ||
      (var.server_image.source == "shared_image_gallery" && var.server_image.shared_image_gallery_image_id != null && var.server_image.marketplace == null)
    )
    error_message = "server_image.source must be 'marketplace' (with marketplace block) or 'shared_image_gallery' (with shared_image_gallery_image_id)."
  }
}

variable "server_vm_size" {
  type        = string
  description = "VM size for the CycleCloud server."
  default     = "Standard_D4s_v5"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource (merged with module-level defaults)."
  default     = {}
}

variable "vnet_address_space" {
  type        = list(string)
  description = "VNet CIDR space. Must accommodate /23 cluster + /26 server + /26 private_endpoint + /26 AzureBastionSubnet."
  default     = ["10.150.0.0/16"]
}
