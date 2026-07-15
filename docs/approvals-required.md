# Approvals Required

Complete these before any deployment (Phase 1).

## Sign-offs
| Item | Owner | Status |
|------|-------|--------|
| Subscription + Tenant confirmed | Azure Admin | ☐ |
| Existing Resource Group reuse confirmed | You | ☐ |
| CIDR allocation (VNet + 2 subnets) non-overlapping | Network team | ☐ |
| Shared resource reuse (ACR/KV/Storage/LAW/AG) decided | Platform | ☐ |
| SP app registration + client secret created; Owner on RG | Platform/Security | ☐ |
| `AZURE_CLIENT_SECRET` stored as GitHub Secret (masked) | Platform | ☐ |
| Terraform backend storage bootstrapped | Platform | ☐ |
| Database authentication option (A/B/C) chosen | DBA/Security | ☐ |
| Budget + POC expiry approved | Owner/Finance | ☐ |
| Resource providers registered | Platform | ☐ |
| Branch protection + environment reviewers set | Platform | ☐ |

## Required Azure resource providers
`Microsoft.DBforPostgreSQL`, `Microsoft.App`, `Microsoft.ContainerRegistry`,
`Microsoft.KeyVault`, `Microsoft.Storage`, `Microsoft.OperationalInsights`,
`Microsoft.Insights`, `Microsoft.Network`, `Microsoft.ManagedIdentity`.

## GitHub configuration required
Repository **Variables**: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
`AZURE_SUBSCRIPTION_ID`, `ACR_NAME`, `ACR_LOGIN_SERVER`, `JOB_NAME`,
`RESOURCE_GROUP`, `STORAGE_ACCOUNT`, `BACKUP_CONTAINER`.
Repository **Secret** (masked): `AZURE_CLIENT_SECRET` (SP client secret).
Environments: `dev` (+ prod later) with required reviewers.

## Decisions still needed from you
1. Password handling **Option A / B / C** (see security-design.md).
2. Confirm/replace default CIDRs with Network-approved ranges.
3. Confirm which shared services (if any) to reuse and provide their resource IDs.
