variable "create_private_dns_zone" {
  type        = bool
  description = "Create the private DNS zone or reuse existing."
}

variable "existing_private_dns_zone_id" {
  type        = string
  description = "Existing private DNS zone resource ID (when reusing)."
  default     = null
  nullable    = true
}

variable "create_vnet_link" {
  type        = bool
  description = "Create the private DNS VNet link."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for new DNS resources."
}

variable "dns_zone_name" {
  type        = string
  description = "Private DNS zone name."
}

variable "dns_link_name" {
  type        = string
  description = "Private DNS VNet link name."
}

variable "virtual_network_id" {
  type        = string
  description = "VNet resource ID to link."
}

variable "tags" {
  type        = map(string)
  description = "Tags."
  default     = {}
}
