variable "access_mode" {
  type        = string
  description = "'bastion' or 'public_ip'. Drives whether AzureBastionSubnet + Bastion are created."
}

variable "allowed_source_ips" {
  type        = list(string)
  description = "Operator source IPs (CIDR) allowed inbound to the server subnet when access_mode = 'public_ip'."
  default     = []
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "naming_token" {
  type        = string
  description = "Naming suffix used in every resource name produced by this module."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group hosting the network resources."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}

variable "vnet_address_space" {
  type        = list(string)
  description = "VNet CIDR space. Subnet CIDRs are computed via cidrsubnet()."
}
