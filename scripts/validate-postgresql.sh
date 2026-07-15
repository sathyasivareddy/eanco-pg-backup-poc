#!/usr/bin/env bash
# =============================================================================
# validate-postgresql.sh — from a VNet-connected host, run the DB validation SQL.
# Password is read from Key Vault (never passed as an argument or logged).
# Usage:
#   KV_NAME=<kv> KV_SECRET=<secret> PGHOST=<fqdn> PGUSER=<user> PGDATABASE=<db> \
#   ./scripts/validate-postgresql.sh
# =============================================================================
set -Eeuo pipefail

: "${PGHOST:?}" "${PGUSER:?}" "${PGDATABASE:?}" "${KV_NAME:?}" "${KV_SECRET:?}"
: "${PGPORT:=5432}" "${PGSSLMODE:=require}"

command -v psql >/dev/null || { echo "psql required"; exit 1; }
command -v az >/dev/null || { echo "az required"; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL="${HERE}/../database/003-validate-data.sql"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export PGPASSFILE="${TMP}/.pgpass"
umask 077

# Fetch password from Key Vault into PGPASSFILE (not echoed).
pw="$(az keyvault secret show --vault-name "$KV_NAME" --name "$KV_SECRET" --query value -o tsv)"
printf '%s:%s:%s:%s:%s\n' "$PGHOST" "$PGPORT" "$PGDATABASE" "$PGUSER" "$pw" > "$PGPASSFILE"
chmod 0600 "$PGPASSFILE"
unset pw

echo ">> Running validation against ${PGDATABASE}"
PGSSLMODE="$PGSSLMODE" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -w \
  -v ON_ERROR_STOP=1 -f "$SQL"
echo "PASS: validation completed"
