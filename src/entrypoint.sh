#!/usr/bin/env bash
# =============================================================================
# entrypoint.sh — runs the backup job.
# Strict shell mode + traps for graceful shutdown.
# =============================================================================
set -Eeuo pipefail

log_json() {
  printf '{"timestamp":"%s","layer":"entrypoint","status":"%s","message":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${1}" "${2}"
}

on_term() {
  log_json "terminating" "Received SIGTERM/SIGINT; shutting down"
  exit 143
}
trap on_term SIGTERM SIGINT

exec /usr/local/bin/backup.sh
