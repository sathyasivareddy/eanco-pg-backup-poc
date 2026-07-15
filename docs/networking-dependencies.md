# Networking Dependencies

The backup job requires **private outbound** connectivity only. No inbound.

## Outbound flow matrix

| Source subnet | Destination | Port | Protocol | Purpose | DNS zone | Responsible team |
|---------------|-------------|------|----------|---------|----------|------------------|
| Container Apps subnet | PostgreSQL Flexible Server | 5432 | TCP/TLS | pg_dump | privatelink.postgres.database.azure.com | DBA / Network |
| Container Apps subnet | Key Vault | 443 | HTTPS | read DB password | privatelink.vaultcore.azure.net (if PE) or public KV endpoint | Security / Network |
| Container Apps subnet | Blob Storage | 443 | HTTPS | upload backups | privatelink.blob.core.windows.net (if PE) or public | Platform / Network |
| Container Apps subnet | Azure Container Registry | 443 | HTTPS | image pull | privatelink.azurecr.io (if PE) or public | Platform / Network |
| Container Apps subnet | Microsoft Entra ID | 443 | HTTPS | token (IMDS/AAD) | login.microsoftonline.com | Identity |
| Container Apps subnet | Azure Monitor / ACA platform | 443 | HTTPS | logs, control plane | (Azure managed) | Platform |
| Container Apps subnet | IMDS 169.254.169.254 | 80 | HTTP | managed identity token | n/a (link-local) | Platform |

## Subnet requirements
- **PostgreSQL subnet:** dedicated, delegated to
  `Microsoft.DBforPostgreSQL/flexibleServers`. Not shared.
- **Container Apps subnet:** dedicated exclusively to the ACA environment.
  `/27` minimum; `/23` recommended for Consumption. Not shared with PostgreSQL,
  private endpoints, VMs, or other services.

## Firewall / NVA
No Azure Firewall, NAT Gateway, routes, or NSG rules are created here. If a
firewall/NVA exists, request an outbound allowlist for the destinations above.
Private DNS must resolve the PostgreSQL FQDN to a private IP from the ACA subnet
(validate with `scripts/validate-private-dns.sh`).

## CIDR approval
Selected for this POC (change per environment if needed): VNet `10.59.0.0/22`,
PostgreSQL subnet `10.59.0.0/24`, Container Apps subnet `10.59.1.0/24`. Both /24
subnets are within the /22 and do not overlap. Confirm with the Network team that
`10.59.0.0/22` does not overlap existing address space before applying.
