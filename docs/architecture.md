# Architecture

## Overview
A cost-optimized, production-standard Azure PostgreSQL backup solution for a POC.
A private PostgreSQL Flexible Server is backed up by a Container Apps Job running
`pg_dump` over private VNet connectivity, with checksum + blob verification,
structured logging, alerting, and restore validation.

## Components
- **Networking:** VNet, PostgreSQL delegated subnet, Container Apps infra subnet,
  private DNS zone + VNet link. (State 1)
- **Database:** PostgreSQL Flexible Server (Burstable B1ms), one POC database. (State 1)
- **Identity:** User-Assigned Managed Identity for the job runtime. (State 2)
- **Registry:** Azure Container Registry (admin disabled). (State 2)
- **Storage:** StorageV2 account + private blob container + lifecycle policy. (State 2)
- **Secrets:** Key Vault (RBAC data plane); DB password secret created out-of-band. (State 2)
- **Compute:** Container Apps Environment (Consumption, internal) + scheduled Job. (State 2)
- **Observability:** Log Analytics + Action Group + critical alerts. (State 2)

## Data flow (backup)
1. Job starts (schedule or manual, control plane).
2. Job authenticates with UAMI, reads DB password from Key Vault.
3. Job connects privately to PostgreSQL (5432, TLS).
4. `pg_dump` produces a compressed custom-format dump in `/tmp`.
5. SHA-256 checksum generated.
6. Dump + checksum uploaded to Blob Storage (Managed Identity, AAD).
7. Blob existence verified; structured JSON logs emitted.
8. Temp files + PGPASSFILE deleted. Exit 0 only on full success.

## Trust boundaries
- No public inbound to the job or the environment.
- Private outbound only (PostgreSQL, Key Vault, Storage, ACR, Entra, Monitor).
- CI/CD via GitHub OIDC (no secrets); runtime via Managed Identity.

See [architecture-diagram.md](architecture-diagram.md), [two-state-design.md](two-state-design.md),
and [security-design.md](security-design.md).
