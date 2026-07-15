# Read the EXISTING resource group (reused, never owned).
data "azurerm_resource_group" "existing" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# OPTIONAL (DISABLED BY DEFAULT): read State 1 outputs via remote state.
# Prefer passing explicit resource IDs as variables (stronger state separation:
# State 2 does not gain read access to the entire State 1 file).
# Enable only if you accept the coupling and grant State 2 read on State 1's blob.
# -----------------------------------------------------------------------------
# data "terraform_remote_state" "foundation" {
#   count   = var.use_remote_state_foundation ? 1 : 0
#   backend = "azurerm"
#   config = {
#     resource_group_name  = var.foundation_backend_resource_group_name
#     storage_account_name = var.foundation_backend_storage_account_name
#     container_name       = var.foundation_backend_container_name
#     key                  = "eanco/poc/postgresql-foundation.tfstate"
#     use_azuread_auth     = true
#   }
# }
