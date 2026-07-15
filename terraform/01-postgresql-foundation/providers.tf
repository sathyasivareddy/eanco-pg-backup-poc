provider "azurerm" {
  features {
    resource_group {
      # Never let this state delete a resource group that still has resources.
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }

  # subscription_id and tenant_id are supplied via ARM_SUBSCRIPTION_ID / ARM_TENANT_ID
  # environment variables (OIDC in CI). They can also be set explicitly if required.
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # Skip automatic provider registration; providers are pre-registered by platform.
  resource_provider_registrations = "none"
}
