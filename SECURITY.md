# Security Policy

## Reporting a vulnerability
Report suspected vulnerabilities privately to the security team
(replace with your channel, e.g. `security@winwire.com`). Do **not** open a public
issue for security reports.

## Secrets handling — hard rules
Secrets are **never** stored in any of the following:
- Terraform variables, `terraform.tfvars`, `*.auto.tfvars`, or Terraform outputs
- GitHub Secrets/Variables used to hold DB passwords, GitHub Actions logs
- Docker images, image layers, or build arguments
- Container Apps plain-text environment variables
- This repository or documentation

The PostgreSQL password is stored **only** in Azure Key Vault and is created
**out-of-band** by an authorized DBA/platform operator. Configuration stores only
the Key Vault **secret name / URI**.

> If PostgreSQL password authentication is used, the admin password may be
> persisted in Terraform **state** even when marked `sensitive`. See
> `docs/security-design.md` (Options A/B/C) before choosing.

## Identities
- **CI/CD (deployment):** GitHub Actions **OIDC** federated identity. No client secrets, no SAS tokens.
- **Runtime:** dedicated **User-Assigned Managed Identity** with least privilege:
  - `AcrPull` (ACR scope)
  - `Key Vault Secrets User` (Key Vault scope)
  - `Storage Blob Data Contributor` (container/account scope)

The runtime identity must **never** be granted `Owner`, `User Access Administrator`,
`Contributor` at subscription/RG, `Key Vault Administrator`, `Storage Account
Contributor`, or `AcrPush`.

## Platform security baselines
- PostgreSQL public network access disabled; private VNet access + TLS required.
- Storage: HTTPS-only, TLS >= 1.2, public blob access disabled, shared-key disabled where supported.
- ACR admin account disabled; images deployed by immutable digest.
- Key Vault soft-delete enabled; purge protection enabled for production.
- Sensitive Terraform outputs suppressed.

## Supply chain
- Third-party GitHub Actions pinned to approved versions / commit SHAs.
- Scans in CI: tflint, Checkov/tfsec (IaC), ShellCheck, Trivy (image + filesystem),
  secret scanning, SBOM generation.
