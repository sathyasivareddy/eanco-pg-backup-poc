terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Least-privilege RBAC for the runtime User-Assigned Managed Identity.

# AcrPull at the ACR scope.
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = var.principal_id
}

# Key Vault Secrets User at the Key Vault scope.
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.principal_id
}

# Storage Blob Data Contributor at container (preferred) or account scope.
resource "azurerm_role_assignment" "blob_contributor" {
  scope                = var.storage_blob_rbac_scope == "container" ? var.storage_container_resource_manager_id : var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.principal_id
}
