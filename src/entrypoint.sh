#!/usr/bin/env bash
# =============================================================================
# entrypoint.sh — dispatches to the requested MODE (backup|restore-test|health).
# Strict shell mode + traps for graceful shutdown and cleanup.
# =============================================================================
set -Eeuo pipefail

MODE="${MODE:-backup}"

log_json() {
  # Minimal structured logger for the entrypoint layer.
  printf '{"timestamp":"%s","layer":"entrypoint","status":"%s","message":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${1}" "${2}"
}

on_term() {
  log_json "terminating" "Received SIGTERM/SIGINT; shutting down"
  exit 143
}
trap on_term SIGTERM SIGINT

case "${MODE}" in
  backup)
    exec /usr/local/bin/backup.sh
    ;;
  restore-test)
    exec /usr/local/bin/restore-test.sh
    ;;
  health)
    exec /usr/local/bin/health-check.sh
    ;;
  *)
    log_json "failed" "Unknown MODE: ${MODE}"
    exit 10
    ;;
esac
