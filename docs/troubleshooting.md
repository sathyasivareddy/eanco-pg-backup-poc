# Troubleshooting

## Job fails with exit 20 (Key Vault)
- UAMI missing **Key Vault Secrets User** on the vault.
- Secret name mismatch (`postgresql_password_secret_name`).
- Secret value not yet created out-of-band by the DBA.
- If KV public access is disabled, ensure private endpoint + DNS reachable from ACA subnet.

## Job fails with exit 30 (DNS)
- Private DNS zone not linked to the VNet, or ACA subnet cannot resolve.
- Run `scripts/validate-private-dns.sh <fqdn>` from a VNet host — must return a private IP.

## Job fails with exit 40 (PostgreSQL connect)
- NSG/firewall blocking 5432 from the ACA subnet.
- Wrong `PGHOST`/`PGUSER`; TLS/`PGSSLMODE` mismatch.
- Server stopped (Burstable stop/start) — start the server.

## Job fails with exit 50 (pg_dump)
- Client/server version mismatch — image uses PostgreSQL 16 client.
- Insufficient `/tmp` space — increase job memory/ephemeral or reduce data.
- Permission denied on objects — check backup role grants.

## Job fails with exit 70/80 (upload/verify)
- UAMI missing **Storage Blob Data Contributor** at container/account scope.
- Storage shared-key disabled and AAD token not acquired — check IMDS/`AZURE_CLIENT_ID`.
- Storage firewall blocking ACA subnet (if PE/network rules enabled).

## Image pull failures
- UAMI missing **AcrPull**; ACR admin is (correctly) disabled.
- Job still on bootstrap image — run `container-deploy` with the real digest.

## No logs in Log Analytics
- ACA environment not linked to the workspace, or ingestion delay (a few minutes).
- Confirm `ContainerAppConsoleLogs_CL` table name in your workspace.

## Terraform: "exactly one of create/reuse" error
- Set `create_virtual_network=true` OR provide `existing_virtual_network_id`, not both/neither.

## Terraform: container_image bootstrap
- First State 2 apply uses `job_bootstrap_image`. Replace with a real ACR digest
  via `container_image` before enabling the schedule.
