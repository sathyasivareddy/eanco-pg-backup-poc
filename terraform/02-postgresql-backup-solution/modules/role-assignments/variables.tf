variable "principal_id" {
  type        = string
  description = "UAMI principal (object) ID."
}

variable "acr_id" {
  type        = string
  description = "ACR resource ID."
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault resource ID."
}

variable "storage_account_id" {
  type        = string
  description = "Storage account resource ID."
}

variable "storage_container_resource_manager_id" {
  type        = string
  description = "Blob container ARM resource ID (for container-scoped RBAC)."
}

variable "storage_blob_rbac_scope" {
  type        = string
  description = "'container' (preferred) or 'account'."
}
