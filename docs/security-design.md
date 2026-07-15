# Security Design

## Identities
- **CI/CD (deployment):** Entra **App Registration + client secret** service
  principal, granted **Owner** on the resource group (POC exception — see below).
  The secret is stored only in the GitHub **Secret** `AZURE_CLIENT_SECRET`,
  masked in logs, never committed. Used for: Terraform plan/apply, image push,
  job update, manual job start.
- **Runtime:** dedicated User-Assigned Managed Identity for the Container Apps Job.

> **POC exception (recorded):** The original design specified OIDC-only (no client
> secret) and least-privilege (no Owner). For this POC we instead use an SP client
> secret with **Owner on the RG**, per delivery decision. Trade-offs: a long-lived
> secret to rotate, and broader-than-needed permissions. Mitigations: secret in
> GitHub Secrets only, environment approvals, rotate on schedule, and migrate to
> OIDC + least-privilege for production.

### Runtime least-privilege RBAC
| Role | Scope |
|------|-------|
| AcrPull | ACR |
| Key Vault Secrets User | Key Vault |
| Storage Blob Data Contributor | Blob **container** (preferred) or account |

Never granted: Owner, User Access Administrator, Subscription/RG Contributor,
Key Vault Administrator, Storage Account Contributor, AcrPush.

## Password handling — choose an option (REQUIRED before State 1)
The PostgreSQL password secret **value** is created out-of-band by an authorized
DBA. Terraform references only the secret **name**. Never store the password in
tfvars, outputs, GitHub, images, or ACA plain-text env.

- **Option A — Password auth, accept password in state.** If Terraform sets the
  admin password (`postgresql_admin_password`), the value is persisted in
  Terraform **state** even when marked `sensitive`. Protect the backend
  (private, RBAC, versioning) and rotate. Supply via
  `TF_VAR_postgresql_admin_password` sourced from Key Vault at plan/apply time.
- **Option B — Microsoft Entra authentication** (if approved/supported by the
  deployment process). Set `postgresql_entra_admin_enabled = true`. Avoids a DB
  password in state.
- **Option C — Create PostgreSQL out-of-band** via an approved platform process;
  State 1 references/imports it instead of creating it.

**Decision (recorded): Option A selected.** Password authentication is used;
`postgresql_password_auth_enabled = true`, Entra admin disabled. The admin
password is supplied at plan/apply via `TF_VAR_postgresql_admin_password` sourced
from Key Vault and is **never committed** to the repo/tfvars. Accepted trade-off:
the value is persisted in Terraform **state**, so the backend must be private,
RBAC-restricted, and versioned. Rotate the password per policy.

## Platform baselines
- PostgreSQL: public access disabled, private VNet, TLS required.
- Storage: HTTPS-only, TLS 1.2+, public blob access disabled, shared-key disabled.
- ACR: admin disabled; images deployed by immutable digest.
- Key Vault: RBAC data plane; soft-delete on; purge protection on for production.
- Sensitive Terraform outputs suppressed; no secrets in outputs.
- Container: non-root (uid 10001), read-only-friendly, `/tmp` scratch, strict
  shell, traps, no secrets in image/build args/layers; TLS never disabled.

## Supply chain / CI security
OIDC-only; minimum workflow permissions; environment approvals; concurrency
locks per state; pin third-party actions to SHAs; fmt/validate/tflint/Checkov/
ShellCheck/Trivy; SBOM generation; secret scanning; protected plan artifacts;
no automatic destroy.

## POC exceptions (document any deviation)
- Key Vault purge protection may be **off** for POC (`false`) — enable for prod.
- Storage LRS + 7-day delete for POC — production retention differs.
- Private endpoints disabled unless policy requires.
