# Backend for STATE 2 — PostgreSQL backup solution.
# Values are supplied at init via -backend-config=backend.hcl (see backend.hcl.example).
terraform {
  backend "azurerm" {
    key = "eanco/poc/postgresql-backup-solution.tfstate"
  }
}
