# Eanco PostgreSQL Backup Solution (POC)

Production-grade but cost-optimized Azure PostgreSQL backup solution for a proof of
concept. A small **Azure Database for PostgreSQL Flexible Server** is backed up by an
**Azure Container Apps Job** running `pg_dump` over private VNet connectivity, with
checksum + blob verification, structured logging, alerting, and restore validation.

> Nothing here deploys automatically. No `terraform apply` is run by this repo.
> Deployment is gated by manual approvals in GitHub Actions.

## Architecture at a glance

```
Resource Group (REUSED, read-only data source)
  └── State 1: terraform/01-postgresql-foundation
        VNet + pg subnet (delegated) + ACA subnet + Private DNS + PostgreSQL Flexible Server + DB
        └── outputs (resource IDs) ──►
              State 2: terraform/02-postgresql-backup-solution
                UAMI + ACR + Storage + Key Vault + Log Analytics + Action Group
                + Container Apps Environment + Container Apps Job + RBAC + alerts + lifecycle
```

- **Two independent Terraform states** with separate backend keys, workflows, and lifecycles.
- **No circular dependency:** State 2 consumes State 1 outputs as explicit resource IDs.
- **No ingress** on the job; **private outbound only** via VNet integration.
- **OIDC** for CI/CD; **Managed Identity** for runtime.

## Repository layout
See [docs/architecture.md](docs/architecture.md) and the tree in
[docs/resource-inventory.md](docs/resource-inventory.md).

| Path | Purpose |
|------|---------|
| `terraform/01-postgresql-foundation` | State 1: network + PostgreSQL |
| `terraform/02-postgresql-backup-solution` | State 2: backup solution |
| `database/` | SQL migrations + validation |
| `src/` | Backup container image + scripts + tests |
| `scripts/` | Operational helper scripts |
| `.github/workflows/` | CI/CD (OIDC) |
| `docs/` | Architecture, runbooks, security, cost, threat model |

## Deployment order (summary)
1. **Approve dependencies** (subscription, RG, CIDRs, backend, auth choice, budget).
2. **Bootstrap backend** (`scripts/bootstrap-backend.sh`) — creates state storage (one-time).
3. **State 1**: init → plan → approve → apply → validate DNS + connectivity.
4. **Initialize DB** via approved private runner / one-time job / DBA.
5. **State 2**: build+scan image → plan → approve → apply → validate RBAC.
6. **Backup validation**: manual run → verify dump/checksum/blob/logs.
7. **Restore validation** against a non-prod test DB.
8. **Enable schedule** only after restore validation passes.

Exact commands: [docs/deployment-runbook.md](docs/deployment-runbook.md).

## Cost note
POC uses **Burstable B1ms** PostgreSQL — acceptable for POC/dev, **not** a production
sizing recommendation. See [docs/cost-estimate.md](docs/cost-estimate.md).

## Security
See [SECURITY.md](SECURITY.md) and [docs/security-design.md](docs/security-design.md).
Choose a password-handling option (A/B/C) before deploying State 1.

## Status / configuration
All environment-specific values are Terraform variables. Example values in
`*.tfvars.example` are **placeholders** — override them with approved values and
provide Tenant ID / subscription via ENV/OIDC.
