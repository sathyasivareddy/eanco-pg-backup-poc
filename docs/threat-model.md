# Threat Model

STRIDE-based summary for the backup solution.

| Threat | Vector | Mitigation |
|--------|--------|------------|
| **Spoofing** | Stolen credentials | OIDC (no static secrets) for CI; Managed Identity for runtime; no passwords in code |
| **Tampering** | Modified backups | SHA-256 checksum stored alongside; blob soft delete; optional immutability/WORM |
| **Repudiation** | Untraceable actions | Structured JSON logs with execution_id; Log Analytics retention; Activity Log |
| **Information disclosure** | Secret leakage | Secrets only in Key Vault; PGPASSFILE 0600 + deleted; no secrets in logs/outputs/state (Option B/C); sanitized log fields |
| **Information disclosure** | Network exposure | Private VNet only; PostgreSQL public access off; storage public blob off; no ingress |
| **Denial of service** | Resource exhaustion | Job timeout + retry limits; scale-to-zero; alerts on long-running/no-backup |
| **Elevation of privilege** | Over-broad RBAC | Least-privilege runtime roles at narrow scopes; no Owner/Contributor; ACR admin disabled; storage shared-key disabled |

## Key assets
- PostgreSQL data and credentials
- Backup blobs (integrity + confidentiality)
- Key Vault secret (DB password)
- Terraform state (may contain admin password under Option A)

## Residual risks
- **Option A** persists the DB password in Terraform state. Mitigate with backend
  RBAC/private access/versioning, or prefer Option B/C.
- Public service endpoints (KV/Storage/ACR) if private endpoints not enabled.
  Mitigate via `create_*_private_endpoint` when policy requires.
- Restore-test job must never target production (guarded by name checks).

## Assumptions
- Network team validates non-overlapping CIDRs.
- Backend storage is access-controlled and versioned.
- Reviewers enforce branch protection + environment approvals.
