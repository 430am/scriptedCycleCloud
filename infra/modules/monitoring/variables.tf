variable "location" {
  type        = string
  description = "Azure region."
}

variable "log_retention_days" {
  type        = number
  description = "Retention for the Log Analytics workspace."
  default     = 30
}

variable "naming_token" {
  type        = string
  description = "Naming suffix for module-scoped resources."
}

variable "naming_token_compact" {
  type        = string
  description = "Compact (alphanumeric, <=14 char) naming token. Used for the monitoring storage account name."
}

variable "pe_subnet_id" {
  type        = string
  description = "Subnet ID hosting private endpoints."
}

variable "private_dns_zone_ids" {
  type        = map(string)
  description = "Map of private DNS zone name -> resource ID. Must contain at minimum: privatelink.{blob,table}.core.windows.net, privatelink.monitor.azure.com, privatelink.{ods,oms}.opinsights.azure.com, privatelink.agentsvc.azure-automation.net."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group hosting the monitoring resources."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}
