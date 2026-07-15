#!/usr/bin/env bash
# =============================================================================
# initialize-database.sh — apply schema + sample data + validation to the POC DB.
# MUST run from a VNet-connected host (self-hosted runner / jump host / DBA box).
# A public GitHub-hosted runner cannot reach the private PostgreSQL server.
# Password is read from Key Vault; never passed as an argument or logged.
#
# Usage:
#   KV_NAME=<kv> KV_SECRET=<secret> PGHOST=<fqdn> PGUSER=<user> PGDATABASE=<db> \
#   ./scripts/initialize-database.sh
# =============================================================================
set -Eeuo pipefail

: "${PGHOST:?}" "${PGUSER:?}" "${PGDATABASE:?}" "${KV_NAME:?}" "${KV_SECRET:?}"
: "${PGPORT:=5432}" "${PGSSLMODE:=require}"

command -v psql >/dev/null || { echo "psql required"; exit 1; }
command -v az >/dev/null || { echo "az required"; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="${HERE}/../database"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export PGPASSFILE="${TMP}/.pgpass"; umask 077
pw="$(az keyvault secret show --vault-name "$KV_NAME" --name "$KV_SECRET" --query value -o tsv)"
printf '%s:%s:%s:%s:%s\n' "$PGHOST" "$PGPORT" "$PGDATABASE" "$PGUSER" "$pw" > "$PGPASSFILE"
chmod 0600 "$PGPASSFILE"; unset pw

run_sql() {
  echo ">> Applying $1"
  PGSSLMODE="$PGSSLMODE" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -w \
    -v ON_ERROR_STOP=1 -f "$1"
}

run_sql "${DB_DIR}/001-create-schema.sql"
run_sql "${DB_DIR}/002-insert-sample-data.sql"
run_sql "${DB_DIR}/003-validate-data.sql"

echo "PASS: database initialized and validated"
