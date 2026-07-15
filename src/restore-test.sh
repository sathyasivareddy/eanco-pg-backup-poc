#!/usr/bin/env bash
# =============================================================================
# restore-test.sh — download the latest backup and restore into a NON-PROD test
# database, then run structural/row-count validation. Never targets production.
#
# Required env:
#   PGHOST PGPORT PGUSER PGSSLMODE KEY_VAULT_URI KEY_VAULT_SECRET_NAME
#   AZURE_CLIENT_ID STORAGE_BLOB_ENDPOINT STORAGE_CONTAINER_NAME
#   RESTORE_TEST_DATABASE  (e.g. eanco_backup_demo_restoretest)
#   RESTORE_BLOB_NAME      (blob path of the .dump to restore)
# Exit codes: 10 input | 20 keyvault | 60 checksum | 70 download | 55 restore | 45 validate
# =============================================================================
set -Eeuo pipefail

: "${PGHOST:?}" "${PGPORT:=5432}" "${PGUSER:?}" "${PGSSLMODE:=require}"
: "${KEY_VAULT_URI:?}" "${KEY_VAULT_SECRET_NAME:?}" "${AZURE_CLIENT_ID:?}"
: "${STORAGE_BLOB_ENDPOINT:?}" "${STORAGE_CONTAINER_NAME:?}"
: "${RESTORE_TEST_DATABASE:?}" "${RESTORE_BLOB_NAME:?}"
: "${STORAGE_API_VERSION:=2021-12-02}"

WORKDIR="$(mktemp -d /tmp/restore.XXXXXX)"
PGPASSFILE="${WORKDIR}/.pgpass"; export PGPASSFILE
DUMP_FILE="${WORKDIR}/restore.dump"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '{"timestamp":"%s","layer":"restore","status":"%s","message":"%s"}\n' "$(now)" "$1" "${2//\"/\'}"; }
die() { log "failed" "$2"; exit "$1"; }

cleanup() { rm -f "$PGPASSFILE" "$DUMP_FILE" 2>/dev/null || true; rm -rf "$WORKDIR" 2>/dev/null || true; }
trap cleanup EXIT
trap 'die 1 "unhandled error"' ERR
trap 'exit 143' SIGTERM SIGINT

# Guard: refuse obviously-production-looking targets.
case "$RESTORE_TEST_DATABASE" in
  *prod*|*production*) die 10 "Refusing to restore into a production-looking database";;
esac

get_token() {
  local resource="$1" resp
  resp="$(curl -sf -H "Metadata: true" --max-time 10 \
    "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=${resource}&client_id=${AZURE_CLIENT_ID}")" || return 1
  printf '%s' "$resp" | jq -r '.access_token // empty'
}

# Fetch DB password from Key Vault.
kv_token="$(get_token "https://vault.azure.net")" || die 20 "KV token failed"
password="$(curl -sf --max-time 15 -H "Authorization: Bearer ${kv_token}" \
  "${KEY_VAULT_URI%/}/secrets/${KEY_VAULT_SECRET_NAME}?api-version=7.4" | jq -r '.value // empty')"
[[ -n "$password" ]] || die 20 "Empty KV secret"
umask 077
printf '%s:%s:%s:%s:%s\n' "$PGHOST" "$PGPORT" "$RESTORE_TEST_DATABASE" "$PGUSER" "$password" > "$PGPASSFILE"
printf '%s:%s:%s:%s:%s\n' "$PGHOST" "$PGPORT" "postgres" "$PGUSER" "$password" >> "$PGPASSFILE"
chmod 0600 "$PGPASSFILE"
unset password

# Download the backup + checksum.
st_token="$(get_token "https://storage.azure.com")" || die 70 "storage token failed"
base_url="${STORAGE_BLOB_ENDPOINT%/}/${STORAGE_CONTAINER_NAME}"
curl -sf --max-time 300 -H "Authorization: Bearer ${st_token}" -H "x-ms-version: ${STORAGE_API_VERSION}" \
  "${base_url}/${RESTORE_BLOB_NAME}" -o "$DUMP_FILE" || die 70 "Backup download failed"
expected_sum="$(curl -sf --max-time 60 -H "Authorization: Bearer ${st_token}" -H "x-ms-version: ${STORAGE_API_VERSION}" \
  "${base_url}/${RESTORE_BLOB_NAME}.sha256" || true)"

# Verify checksum when available.
if [[ -n "${expected_sum}" ]]; then
  actual_sum="$(sha256sum "$DUMP_FILE" | awk '{print $1}')"
  [[ "${expected_sum// /}" == "${actual_sum}" ]] || die 60 "Checksum mismatch"
  log "success" "Checksum verified"
fi

# (Re)create the test database and restore.
PGSSLMODE="$PGSSLMODE" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -w \
  -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS \"${RESTORE_TEST_DATABASE}\";" \
  -c "CREATE DATABASE \"${RESTORE_TEST_DATABASE}\";" || die 55 "Test DB (re)create failed"

PGSSLMODE="$PGSSLMODE" pg_restore -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$RESTORE_TEST_DATABASE" -w \
  --no-owner --no-privileges "$DUMP_FILE" || die 55 "pg_restore failed"
log "success" "Restore completed into ${RESTORE_TEST_DATABASE}"

# Structural + row-count validation (uses repo SQL when mounted, else inline checks).
if [[ -f /work/004-restore-validation.sql ]]; then
  PGSSLMODE="$PGSSLMODE" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$RESTORE_TEST_DATABASE" -w \
    -v ON_ERROR_STOP=1 -f /work/004-restore-validation.sql || die 45 "Validation SQL failed"
else
  PGSSLMODE="$PGSSLMODE" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$RESTORE_TEST_DATABASE" -w \
    -v ON_ERROR_STOP=1 -Atc "
      DO \$\$
      DECLARE c bigint; o bigint; i bigint;
      BEGIN
        SELECT count(*) INTO c FROM eanco_demo.customers;
        SELECT count(*) INTO o FROM eanco_demo.orders;
        SELECT count(*) INTO i FROM eanco_demo.order_items;
        IF c < 3 OR o < 2 OR i < 3 THEN
          RAISE EXCEPTION 'row counts c=% o=% i=%', c, o, i;
        END IF;
      END \$\$;" || die 45 "Inline validation failed"
fi

log "success" "Restore validation PASSED"
exit 0
