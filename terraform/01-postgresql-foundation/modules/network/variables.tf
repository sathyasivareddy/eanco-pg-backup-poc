variable "create_virtual_network" {
  type        = bool
  description = "Create a new VNet or reuse existing."
}

variable "existing_virtual_network_id" {
  type        = string
  description = "Existing VNet resource ID when not creating."
  default     = null
  nullable    = true
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for new network resources."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "vnet_name" {
  type        = string
  description = "VNet name (when creating)."
}

variable "vnet_address_space" {
  type        = list(string)
  description = "VNet address space."
}

variable "create_postgresql_subnet" {
  type        = bool
  description = "Create the PostgreSQL delegated subnet."
}

variable "postgresql_subnet_name" {
  type        = string
  description = "PostgreSQL subnet name."
}

variable "postgresql_subnet_cidr" {
  type        = string
  description = "PostgreSQL subnet CIDR."
}

variable "postgresql_subnet_nsg_id" {
  type        = string
  description = "Optional NSG for the PostgreSQL subnet."
  default     = null
  nullable    = true
}

variable "create_container_apps_subnet" {
  type        = bool
  description = "Create the Container Apps subnet."
}

variable "container_apps_subnet_name" {
  type        = string
  description = "Container Apps subnet name."
}

variable "container_apps_subnet_cidr" {
  type        = string
  description = "Container Apps subnet CIDR."
}

variable "container_apps_subnet_nsg_id" {
  type        = string
  description = "Optional NSG for the Container Apps subnet."
  default     = null
  nullable    = true
}

variable "enable_resource_locks" {
  type        = bool
  description = "Apply CanNotDelete lock to the VNet."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags."
  default     = {}
}
