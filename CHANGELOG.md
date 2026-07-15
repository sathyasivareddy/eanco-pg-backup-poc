# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial two-state Terraform architecture (`01-postgresql-foundation`,
  `02-postgresql-backup-solution`).
- Azure Database for PostgreSQL Flexible Server (POC sizing: Burstable B1ms).
- Sample schema `eanco_demo` (customers, orders, order_items) with migrations.
- Container Apps Job for `pg_dump` backups with checksum + blob verification.
- User-Assigned Managed Identity with least-privilege RBAC.
- GitHub Actions workflows using OIDC (plan/apply/build/deploy/manual/restore/drift).
- Documentation set under `docs/` and operational scripts under `scripts/`.

### Security
- No secrets stored in repo, state (where avoidable), or logs.
- OIDC-only CI/CD; ACR admin disabled; storage shared-key disabled; TLS >= 1.2.
