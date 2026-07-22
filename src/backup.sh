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
  # Streaming keeps only ONE ~100 MiB block on disk at a time; require ~300 MiB.
  [[ "${avail_kb:-0}" -gt 307200 ]] || die 50 "check_tmp" "Insufficient temp space (<300MB) for streaming block buffer"
  log "check_tmp" "success"
}

url_encode() { jq -rn --arg s "$1" '$s|@uri'; }

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

step_stream() {
  # ---------------------------------------------------------------------------
  # Streams pg_dump (custom-format, compressed) directly to a block blob.
  # Only ONE ~100 MiB block is ever written to local disk, so the container
  # needs no large ephemeral storage regardless of database size. The SHA-256
  # of the uploaded content is computed inline via a tee'd fifo.
  # Emits the pg_dump / checksum / upload stages for log continuity.
  # ---------------------------------------------------------------------------
  log "pg_dump" "started"

  local block_size=$(( 100 * 1024 * 1024 ))     # 100 MiB per block
  local block_file="${WORKDIR}/block.bin"
  local blocklist_file="${WORKDIR}/blocklist.xml"
  local shafifo="${WORKDIR}/shafifo"
  CHECKSUM_FILE="${WORKDIR}/dump.sha256"

  BLOB_NAME="$(build_blob_name)"
  local url="${STORAGE_BLOB_ENDPOINT%/}/${STORAGE_CONTAINER_NAME}/${BLOB_NAME}"
  local token; token="$(get_token "https://storage.azure.com")" || die 70 "upload" "storage token failed"

  : > "$blocklist_file"
  rm -f "$shafifo"; mkfifo "$shafifo"
  ( sha256sum < "$shafifo" | awk '{print $1}' > "$CHECKSUM_FILE" ) &
  local sha_pid=$!

  # pg_dump -> tee: one copy to the sha fifo, one to fd 3 for the chunk loop.
  exec 3< <(PGSSLMODE="$PGSSLMODE" pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
              -w -Fc -Z 6 2> "${WORKDIR}/pg_dump.err" | tee "$shafifo")

  local i=0 total=0 raw_id enc_id sz attempt ok
  while :; do
    head -c "$block_size" <&3 > "$block_file" || true
    sz="$(stat -c %s "$block_file" 2>/dev/null || echo 0)"
    [[ "$sz" -gt 0 ]] || break

    # Refresh the storage token every ~3 GB so long streams never hit expiry.
    if (( i > 0 && i % 30 == 0 )); then
      token="$(get_token "https://storage.azure.com")" || die 70 "upload" "token refresh failed at block ${i}"
    fi

    raw_id="$(printf 'block-%09d' "$i" | base64 -w0)"   # fixed-length, base64
    enc_id="$(url_encode "$raw_id")"

    attempt=0; ok=0
    while [[ $attempt -lt 3 ]]; do
      if curl -sf --max-time 600 -X PUT \
          -H "Authorization: Bearer ${token}" \
          -H "x-ms-version: ${STORAGE_API_VERSION}" \
          -H "x-ms-date: $(date -u '+%a, %d %b %Y %H:%M:%S GMT')" \
          --data-binary "@${block_file}" \
          "${url}?comp=block&blockid=${enc_id}" >/dev/null; then ok=1; break; fi
      attempt=$((attempt+1)); sleep 3
    done
    [[ $ok -eq 1 ]] || die 70 "upload" "Put Block failed at block ${i}"

    printf '<Latest>%s</Latest>' "$raw_id" >> "$blocklist_file"
    i=$((i+1)); total=$(( total + sz ))
  done
  exec 3<&- || true
  wait "$sha_pid" 2>/dev/null || true
  rm -f "$block_file" "$shafifo"

  if grep -qiE 'error|fatal' "${WORKDIR}/pg_dump.err" 2>/dev/null; then
    die 50 "pg_dump" "pg_dump reported: $(sanitize "$(tail -n1 "${WORKDIR}/pg_dump.err")")"
  fi
  [[ "$i" -gt 0 ]] || die 50 "pg_dump" "No data produced by pg_dump"
  BACKUP_SIZE_BYTES="$total"
  log "pg_dump" "success"

  [[ -s "$CHECKSUM_FILE" ]] || die 60 "checksum" "Inline sha256 not produced"
  log "checksum" "success"

  # Commit the uploaded blocks into the final blob (Put Block List).
  log "upload" "started"
  token="$(get_token "https://storage.azure.com")" || die 70 "upload" "storage token failed (commit)"
  curl -sf --max-time 120 -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "x-ms-version: ${STORAGE_API_VERSION}" \
    -H "x-ms-date: $(date -u '+%a, %d %b %Y %H:%M:%S GMT')" \
    -H "x-ms-blob-content-type: application/octet-stream" \
    -H "x-ms-meta-environment: ${ENVIRONMENT}" \
    -H "x-ms-meta-database: ${PGDATABASE}" \
    -H "x-ms-meta-server: ${PG_SERVER_NAME}" \
    -H "x-ms-meta-execution_id: ${EXECUTION_ID}" \
    -H "x-ms-meta-sha256: $(cat "$CHECKSUM_FILE")" \
    -H "x-ms-meta-retention: ${BACKUP_RETENTION_LABEL}" \
    -H "x-ms-meta-pg_dump_version: ${PG_DUMP_VERSION}" \
    -H "Content-Type: application/xml" \
    --data-binary "<?xml version=\"1.0\" encoding=\"utf-8\"?><BlockList>$(cat "$blocklist_file")</BlockList>" \
    "${url}?comp=blocklist" >/dev/null || die 70 "upload" "Put Block List (commit) failed"

  # Upload the checksum sidecar (tiny).
  put_blob "$CHECKSUM_FILE" "${BLOB_NAME}.sha256" "text/plain" \
    -H "x-ms-meta-environment: ${ENVIRONMENT}" || die 70 "upload" "Checksum sidecar upload failed"
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
  step_stream
  step_verify_blob
  log "completed" "success" "" "Backup completed and verified"
  exit 0
}

# Only run main when executed directly (allows sourcing in unit tests).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
