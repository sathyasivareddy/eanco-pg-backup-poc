# State Dependencies

## Direction
State 1 → State 2 (one-way). State 1 must be applied and validated first.

## State 1 outputs → State 2 variables

| State 1 output | State 2 variable | Purpose |
|----------------|------------------|---------|
| `resource_group_name` | `resource_group_name` | Reuse RG |
| `location` | `location` | Region |
| `postgresql_server_id` | `postgresql_server_id` | Reference / audit |
| `postgresql_server_fqdn` | `postgresql_server_fqdn` | Job DB host |
| `postgresql_database_name` | `postgresql_database_name` | Job DB name |
| `postgresql_admin_username` | `postgresql_admin_username` | Job DB user (non-secret) |
| `virtual_network_id` | `virtual_network_id` | Reference |
| `container_apps_subnet_id` | `container_apps_subnet_id` | ACA env integration |
| `postgresql_subnet_id` | (not required by State 2) | Owned by State 1 |
| `postgresql_private_dns_zone_id` | (not required by State 2) | Owned by State 1 |

## Passing values
```bash
# From State 1:
cd terraform/01-postgresql-foundation
terraform output -json > /tmp/state1.json

# Populate State 2 terraform.tfvars using those outputs (example):
jq -r '"postgresql_server_fqdn = \"" + .postgresql_server_fqdn.value + "\""' /tmp/state1.json
```

## Optional remote-state (disabled)
`data.tf` in State 2 contains a commented `terraform_remote_state` block. Prefer
explicit IDs; enabling remote state grants State 2 read access to State 1's file
and couples their lifecycles.
