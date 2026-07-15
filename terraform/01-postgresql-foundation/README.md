# State 1 — PostgreSQL Foundation

Creates the private network and Azure Database for PostgreSQL Flexible Server.
This state **reads** the existing resource group and never owns/deletes it.

## Backend
- Key: `eanco/poc/postgresql-foundation.tfstate`
- Configure via `backend.hcl` (copy from `backend.hcl.example`).

## What it manages
- Virtual Network (create or reuse)
- PostgreSQL delegated subnet (`Microsoft.DBforPostgreSQL/flexibleServers`)
- Container Apps infrastructure subnet
- PostgreSQL private DNS zone + VNet link
- PostgreSQL Flexible Server (private access, TLS required) + POC database

## What it does NOT manage
- Resource Group (read-only data source)
- Container Apps Environment or backup job (State 2)
- Any shared backup services (State 2)

## Outputs (explicit inputs to State 2)
`resource_group_name`, `location`, `postgresql_server_id`, `postgresql_server_fqdn`,
`postgresql_database_name`, `postgresql_admin_username`, `virtual_network_id`,
`postgresql_subnet_id`, `container_apps_subnet_id`, `postgresql_private_dns_zone_id`.

## Usage
```bash
cd terraform/01-postgresql-foundation
cp backend.hcl.example backend.hcl        # edit approved values
cp terraform.tfvars.example terraform.tfvars   # edit approved values

export ARM_SUBSCRIPTION_ID="dae60e3b-6b95-4e36-877f-50c54edcd377"
export ARM_TENANT_ID="<tenant-id>"
# Option A only (password auth): source from Key Vault, never hardcode:
# export TF_VAR_postgresql_admin_password="$(az keyvault secret show --vault-name <kv> --name <secret> --query value -o tsv)"

terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

## Password handling
Choose Option A/B/C in `docs/security-design.md` before enabling password auth.
Terraform never creates the real Key Vault password secret value.
