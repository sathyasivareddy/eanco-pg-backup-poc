#!/usr/bin/env bash
# =============================================================================
# validate-dependencies.sh — checks required tooling + Azure context are present
# before running Terraform. Read-only; creates nothing.
# =============================================================================
set -Eeuo pipefail

fail=0
need() { command -v "$1" >/dev/null 2>&1 && echo "ok: $1" || { echo "MISSING: $1"; fail=1; }; }

echo "== Tooling =="
need az
need terraform
need docker
need jq
need shellcheck
need tflint
need checkov
need trivy

echo "== Azure context =="
if az account show >/dev/null 2>&1; then
  echo "ok: az logged in -> $(az account show --query name -o tsv)"
else
  echo "MISSING: az login / OIDC context"; fail=1
fi

echo "== Required env (recommended) =="
for v in ARM_SUBSCRIPTION_ID ARM_TENANT_ID; do
  if [[ -n "${!v:-}" ]]; then echo "ok: ${v} set"; else echo "warn: ${v} not set (relying on ambient auth)"; fi
done

exit "$fail"
