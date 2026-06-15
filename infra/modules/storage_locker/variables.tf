variable "caller_object_id" {
  type        = string
  description = "AAD object ID of the principal running Terraform; granted Storage Blob Data Owner so the cyclecloud container can be created over AAD auth (shared keys disabled)."
}

variable "diagnostic_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID for blob service diagnostic settings."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "naming_token" {
  type        = string
  description = "Naming suffix for module-scoped resources (PE, role assignment)."
}

variable "naming_token_compact" {
  type        = string
  description = "Compact (alphanumeric, <=14 char) naming token used for the storage account name."
}

variable "pe_subnet_id" {
  type        = string
  description = "Subnet ID hosting private endpoints."
}

variable "private_dns_zone_id_blob" {
  type        = string
  description = "Resource ID of privatelink.blob.core.windows.net."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group hosting the locker storage account."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}
