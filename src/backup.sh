#!/usr/bin/env bash
# =============================================================================
# backup.sh — pg_dump a PostgreSQL database over private VNet and upload to Blob.
#
# Security:
#   - No passwords on the command line or in logs.
#   - Password fetched from Key Vault at runtime using the User-Assigned Managed
#     Identity (via IMDS). Written only to a 0600 PGPASSFILE, deleted on exit.
#   - TLS enforced (PGSSLMODE). No connection strings logged.
#
# Categorized exit codes:
#   10 Input validation | 20 Key Vault | 30 DNS/network | 40 PostgreSQL connect
#   50 pg_dump | 60 Checksum | 70 Blob upload | 80 Blob verify | 90 Cleanup
# =============================================================================
set -Eeuo pipefail

# ----------------------------- configuration --------------------------------
: "${ENVIRONMENT:?}" "${PGHOST:?}" "${PGPORT:=5432}" "${PGUSER:?}" "${PGDATABASE:?}"
: "${PGSSLMODE:=require}" "${PG_SERVER_NAME:?}"
: "${KEY_VAULT_URI:?}" "${KEY_VAULT_SECRET_NAME:?}"
: "${STORAGE_ACCOUNT_NAME:?}" "${STORAGE_BLOB_ENDPOINT:?}" "${STORAGE_CONTAINER_NAME:?}"
: "${AZURE_CLIENT_ID:?}"
: "${IMAGE_DIGEST:=unknown}" "${BACKUP_RETENTION_LABEL:=poc}"

WORKDIR="$(mktemp -d /tmp/backup.XXXXXX)"
PGPASSFILE="${WORKDIR}/.pgpass"
export PGPASSFILE
EXECUTION_ID="${CONTAINER_APP_REPLICA_NAME:-$(cat /proc/sys/kernel/random/uuid)}"
START_EPOCH="$(date -u +%s)"
STORAGE_API_VERSION="2021-12-02"
BLOB_NAME=""
DUMP_FILE=""
CHECKSUM_FILE=""
PG_DUMP_VERSION="$(pg_dump --version 2>/dev/null | awk '{print $NF}' || echo unknown)"

# ----------------------------- logging --------------------------------------
sanitize() { printf '%s' "${1:-}" | tr -d '\r' | sed -e 's/"/'"'"'/g' | cut -c1-500; }

log() {
  # log <stage> <status> [error_code] [message]
  local stage="$1" status="$2" code="${3:-}" msg="${4:-}"
  local now dur
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  dur=$(( $(date -u +%s) - START_EPOCH ))
  printf '{"execution_id":"%s","timestamp":"%s","environment":"%s","server_identifier":"%s","database_identifier":"%s","backup_stage":"%s","status":"%s","duration_seconds":%d,"backup_size_bytes":%s,"blob_name":"%s","pg_dump_version":"%s","image_digest":"%s","error_code":"%s","sanitized_error_message":"%s"}\n' \
    "$(sanitize "$EXECUTION_ID")" "$now" "$(sanitize "$ENVIRONMENT")" "$(sanitize "$PG_SERVER_NAME")" \
    "$(sanitize "$PGDATABASE")" "$(sanitize "$stage")" "$(sanitize "$status")" "$dur" \
    "${BACKUP_SIZE_BYTES:-0}" "$(sanitize "$BLOB_NAME")" "$(sanitize "$PG_DUMP_VERSION")" \
    "$(sanitize "$IMAGE_DIGEST")" "$(sanitize "$code")" "$(sanitize "$msg")"
}

# ----------------------------- traps ----------------------------------------
cleanup() {
  local rc=$?
  # Best-effort secure cleanup; never fail the job solely on cleanup.
  if [[ -f "$PGPASSFILE" ]]; then rm -f "$PGPASSFILE" || true; fi
  if [[ -n "${DUMP_FILE}" && -f "${DUMP_FILE}" ]]; then rm -f "${DUMP_FILE}" || true; fi
  if [[ -n "${CHECKSUM_FILE}" && -f "${CHECKSUM_FILE}" ]]; then rm -f "${CHECKSUM_FILE}" || true; fi
  if [[ -d "$WORKDIR" ]]; then rm -rf "$WORKDIR" || true; fi
  if [[ $rc -ne 0 ]]; then log "cleanup" "failed" "$rc" "Job exited with non-zero code"; fi
  return 0
}
on_error() {
  local rc=$?
  local line="${1:-?}"
  log "fatal" "failed" "$rc" "Unhandled error near line ${line}"
}
trap 'on_error $LINENO' ERR
trap cleanup EXIT
trap 'exit 143' SIGTERM SIGINT

die() { local code="$1" stage="$2" msg="$3"; log "$stage" "failed" "$code" "$msg"; exit "$code"; }

# ----------------------------- managed identity token -----------------------
get_token() {
  # get_token <resource> -> prints access_token
  # Supports both the Container Apps/App Service identity endpoint
  # (IDENTITY_ENDPOINT + IDENTITY_HEADER) and the VM/VMSS IMDS endpoint.
  local resource="$1" resp token
  if [[ -n "${IDENTITY_ENDPOINT:-}" && -n "${IDENTITY_HEADER:-}" ]]; then
    resp="$(curl -sf --max-time 10 \
      -H "X-IDENTITY-HEADER: ${IDENTITY_HEADER}" \
      "${IDENTITY_ENDPOINT}?api-version=2019-08-01&resource=${resource}&client_id=${AZURE_CLIENT_ID}")" \
      || return 1
  else
    resp="$(curl -sf -H "Metadata: true" --max-time 10 \
      "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=${resource}&client_id=${AZURE_CLIENT_ID}")" \
      || return 1
  fi
  token="$(printf '%s' "$resp" | jq -r '.access_token // empty')"
  [[ -n "$token" ]] || return 1
  printf '%s' "$token"
}

# ----------------------------- blob path sanitization -----------------------
sanitize_path_segment() {
  # Only allow safe chars in path segments to avoid traversal/injection.
  printf '%s' "${1:-}" | tr -cd 'A-Za-z0-9._-' | cut -c1-128
}

build_blob_name() {
  local env srv db ts
  env="$(sanitize_path_segment "$ENVIRONMENT")"
  srv="$(sanitize_path_segment "$PG_SERVER_NAME")"
  db="$(sanitize_path_segment "$PGDATABASE")"
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  local exec_id; exec_id="$(sanitize_path_segment "$EXECUTION_ID")"
  printf '%s/%s/%s/%s/%s/%s/%s_%s_%s.dump' \
    "$env" "$srv" "$db" "$(date -u +%Y)" "$(date -u +%m)" "$(date -u +%d)" \
    "$db" "$ts" "$exec_id"
}

# ----------------------------- steps ----------------------------------------
step_validate_input() {
  log "validate_input" "started"
  [[ "$PGPORT" =~ ^[0-9]+$ ]] || die 10 "validate_input" "PGPORT not numeric"
  case "$PGSSLMODE" in require|verify-ca|verify-full) ;; *) die 10 "validate_input" "Invalid PGSSLMODE";; esac
  log "validate_input" "success"
}

step_fetch_secret() {
  log "keyvault" "started"
  local kv_token secret_resp password
  kv_token="$(get_token "https://vault.azure.net")" || die 20 "keyvault" "Failed to obtain KV token via IMDS"
  secret_resp="$(curl -sf --max-time 15 -H "Authorization: Bearer ${kv_token}" \
    "${KEY_VAULT_URI%/}/secrets/${KEY_VAULT_SECRET_NAME}?api-version=7.4")" \
    || die 20 "keyvault" "Failed to read secret from Key Vault"
  password="$(printf '%s' "$secret_resp" | jq -r '.value // empty')"
  [[ -n "$password" ]] || die 20 "keyvault" "Empty secret value"
  # Write 0600 PGPASSFILE: hostname:port:database:username:password
  umask 077
  printf '%s:%s:%s:%s:%s\n' "$PGHOST" "$PGPORT" "$PGDATABASE" "$PGUSER" "$password" > "$PGPASSFILE"
  chmod 0600 "$PGPASSFILE"
  unset password secret_resp
  log "keyvault" "success"
}

step_validate_dns() {
  log "dns" "started"
  # getent/nslookup may be absent; use curl-based resolution via bash /dev/tcp fallback.
  if command -v getent >/dev/null 2>&1; then
    getent hosts "$PGHOST" >/dev/null 2>&1 || die 30 "dns" "DNS resolution failed for host"
  else
    # Fallback: attempt a TCP connect which also proves resolution.
    timeout 5 bash -c ">/dev/tcp/${PGHOST}/${PGPORT}" 2>/dev/null || die 30 "dns" "DNS/connect check failed"
  fi
  log "dns" "success"
}

step_validate_tcp() {
  log "tcp" "started"
  timeout 10 bash -c ">/dev/tcp/${PGHOST}/${PGPORT}" 2>/dev/null || die 40 "tcp" "TCP connect to 5432 failed"
  log "tcp" "success"
}

step_probe_query() {
  log "probe_query" "started"
  PGSSLMODE="$PGSSLMODE" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
    -w -Atc "SELECT 1;" >/dev/null 2>&1 || die 40 "probe_query" "Lightweight query failed"
  log "probe_query" "success"
}

step_check_tmp() {
  log "check_tmp" "started"
  local avail_kb
  avail_kb="$(df -Pk "$WORKDIR" | awk 'NR==2{print $4}')"
  [[ "${avail_kb:-0}" -gt 51200 ]] || die 50 "check_tmp" "Insufficient temp space (<50MB)"
  log "check_tmp" "success"
}

step_pg_dump() {
  log "pg_dump" "started"
  DUMP_FILE="${WORKDIR}/${PGDATABASE}.dump"
  # Custom format (-Fc) is compressed and restorable via pg_restore.
  if ! PGSSLMODE="$PGSSLMODE" pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
        -w -Fc -Z 6 -f "$DUMP_FILE" 2> "${WORKDIR}/pg_dump.err"; then
    die 50 "pg_dump" "pg_dump failed: $(sanitize "$(tail -n1 "${WORKDIR}/pg_dump.err" 2>/dev/null)")"
  fi
  [[ -f "$DUMP_FILE" ]] || die 50 "pg_dump" "Dump file missing"
  BACKUP_SIZE_BYTES="$(stat -c %s "$DUMP_FILE" 2>/dev/null || echo 0)"
  [[ "${BACKUP_SIZE_BYTES}" -gt 0 ]] || die 50 "pg_dump" "Dump file is empty"
  log "pg_dump" "success"
}

step_checksum() {
  log "checksum" "started"
  CHECKSUM_FILE="${DUMP_FILE}.sha256"
  sha256sum "$DUMP_FILE" | awk '{print $1}' > "$CHECKSUM_FILE" || die 60 "checksum" "sha256 failed"
  [[ -s "$CHECKSUM_FILE" ]] || die 60 "checksum" "Empty checksum"
  log "checksum" "success"
}

put_blob() {
  # put_blob <local_file> <blob_name> <content_type> [extra metadata headers...]
  local file="$1" blob="$2" ctype="$3"; shift 3
  local token; token="$(get_token "https://storage.azure.com")" || return 70
  local url="${STORAGE_BLOB_ENDPOINT%/}/${STORAGE_CONTAINER_NAME}/${blob}"
  curl -sf --max-time 120 -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "x-ms-version: ${STORAGE_API_VERSION}" \
    -H "x-ms-blob-type: BlockBlob" \
    -H "x-ms-date: $(date -u '+%a, %d %b %Y %H:%M:%S GMT')" \
    -H "Content-Type: ${ctype}" \
    "$@" \
    --data-binary "@${file}" \
    "$url" >/dev/null
}

step_upload() {
  log "upload" "started"
  BLOB_NAME="$(build_blob_name)"
  put_blob "$DUMP_FILE" "$BLOB_NAME" "application/octet-stream" \
    -H "x-ms-meta-environment: ${ENVIRONMENT}" \
    -H "x-ms-meta-database: ${PGDATABASE}" \
    -H "x-ms-meta-server: ${PG_SERVER_NAME}" \
    -H "x-ms-meta-execution_id: ${EXECUTION_ID}" \
    -H "x-ms-meta-sha256: $(cat "$CHECKSUM_FILE")" \
    -H "x-ms-meta-retention: ${BACKUP_RETENTION_LABEL}" \
    -H "x-ms-meta-pg_dump_version: ${PG_DUMP_VERSION}" \
    || die 70 "upload" "Blob upload failed"
  put_blob "$CHECKSUM_FILE" "${BLOB_NAME}.sha256" "text/plain" \
    -H "x-ms-meta-environment: ${ENVIRONMENT}" \
    || die 70 "upload" "Checksum upload failed"
  log "upload" "success"
}

step_verify_blob() {
  log "verify_blob" "started"
  local token url code
  token="$(get_token "https://storage.azure.com")" || die 80 "verify_blob" "token for verify failed"
  url="${STORAGE_BLOB_ENDPOINT%/}/${STORAGE_CONTAINER_NAME}/${BLOB_NAME}"
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 -I \
    -H "Authorization: Bearer ${token}" -H "x-ms-version: ${STORAGE_API_VERSION}" "$url")"
  [[ "$code" == "200" ]] || die 80 "verify_blob" "Blob HEAD returned ${code}"
  log "verify_blob" "success"
}

main() {
  log "start" "started" "" "Backup run starting"
  step_validate_input
  step_fetch_secret
  step_validate_dns
  step_validate_tcp
  step_probe_query
  step_check_tmp
  step_pg_dump
  step_checksum
  step_upload
  step_verify_blob
  log "completed" "success" "" "Backup completed and verified"
  exit 0
}

# Only run main when executed directly (allows sourcing in unit tests).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
