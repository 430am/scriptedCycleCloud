variable "allowed_source_ips" {
  type        = list(string)
  description = "Operator source IPs (CIDR) added to the Key Vault firewall allow-list."
  default     = []
}

variable "caller_object_id" {
  type        = string
  description = "AAD object ID of the principal running Terraform; granted Key Vault Administrator so secret writes succeed."
}

variable "diagnostic_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID for Key Vault diagnostic settings."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "naming_token" {
  type        = string
  description = "Naming suffix for module-scoped resources (UAI, PE)."
}

variable "naming_token_compact" {
  type        = string
  description = "Compact (alphanumeric, <=14 char) naming token. Used for the Key Vault name, which is limited to 24 chars and disallows underscores."
}

variable "pe_subnet_id" {
  type        = string
  description = "Subnet ID hosting private endpoints."
}

variable "private_dns_zone_id_vault" {
  type        = string
  description = "Resource ID of privatelink.vaultcore.azure.net."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group hosting Key Vault, UAI, and the private endpoint."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}
