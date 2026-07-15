# Contributing

## Prerequisites
- Terraform `>= 1.9.0`
- Azure CLI `>= 2.60`
- Docker (for building/testing the backup image)
- ShellCheck, tflint, Checkov (or tfsec), Trivy for local validation
- `psql` / `pg_dump` (PostgreSQL 16 client) for DB tasks

## Branching & reviews
- Default branch: `main` (protected).
- Feature branches: `feat/<short-desc>`, fixes: `fix/<short-desc>`.
- All changes via Pull Request. CODEOWNERS review required.
- CI must pass (fmt, validate, tflint, Checkov/tfsec, ShellCheck, Trivy).

## Local validation (run before pushing)
```bash
make fmt          # terraform fmt -recursive
make validate     # terraform validate (both roots, -backend=false)
make lint         # tflint + shellcheck
make security     # checkov/tfsec + trivy fs
make test         # shell unit tests
```

## Commit style
Conventional Commits, e.g. `feat(terraform): add storage lifecycle policy`.

## Rules
- No secrets in commits (enforced by secret scanning).
- Every environment-dependent value must be a Terraform variable.
- Do not run `terraform apply` from a workstation for shared environments — use CI.
- Update relevant docs in `docs/` with any behavioral change.
