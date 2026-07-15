# Backend for STATE 1 — PostgreSQL foundation.
# Values are supplied at init time via -backend-config=backend.hcl (see backend.hcl.example).
# Do NOT hardcode account names/keys here. Authentication uses Azure AD (use_azuread_auth).
terraform {
  backend "azurerm" {
    # key is fixed for this state root; other values come from backend.hcl
    key = "eanco/poc/postgresql-foundation.tfstate"
  }
}
