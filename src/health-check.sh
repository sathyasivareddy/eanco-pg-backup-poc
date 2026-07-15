#!/usr/bin/env bash
# =============================================================================
# health-check.sh — lightweight readiness probe used for diagnostics.
# Validates env, DNS resolution and TCP reachability to PostgreSQL. No secrets.
# Exit codes mirror backup.sh (10 input, 30 dns, 40 tcp).
# =============================================================================
set -Eeuo pipefail

: "${PGHOST:?}" "${PGPORT:=5432}"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '{"timestamp":"%s","layer":"health","status":"%s","message":"%s"}\n' "$(now)" "$1" "$2"; }

trap 'log "failed" "unhandled error"; exit 1' ERR
trap 'exit 143' SIGTERM SIGINT

[[ "$PGPORT" =~ ^[0-9]+$ ]] || { log "failed" "PGPORT not numeric"; exit 10; }

if command -v getent >/dev/null 2>&1; then
  getent hosts "$PGHOST" >/dev/null 2>&1 || { log "failed" "DNS resolution failed"; exit 30; }
fi

if timeout 10 bash -c ">/dev/tcp/${PGHOST}/${PGPORT}" 2>/dev/null; then
  log "success" "PostgreSQL reachable on ${PGPORT}"
  exit 0
else
  log "failed" "TCP connect failed"
  exit 40
fi
