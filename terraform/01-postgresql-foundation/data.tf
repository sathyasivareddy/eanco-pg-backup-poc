# Read the EXISTING resource group. Terraform must never own or delete it.
data "azurerm_resource_group" "existing" {
  name = var.resource_group_name
}

# Current deployer identity (used for optional Key Vault access during bootstrap docs).
data "azurerm_client_config" "current" {}
