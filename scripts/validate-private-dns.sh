#!/usr/bin/env bash
# =============================================================================
# validate-private-dns.sh — from a VNet-connected host, confirm the PostgreSQL
# FQDN resolves to a private IP via the private DNS zone. Read-only.
# Usage: ./scripts/validate-private-dns.sh <postgres-fqdn>
# =============================================================================
set -Eeuo pipefail

FQDN="${1:?PostgreSQL FQDN required}"

echo ">> Resolving ${FQDN}"
if command -v getent >/dev/null 2>&1; then
  ip="$(getent hosts "$FQDN" | awk '{print $1}' | head -n1 || true)"
elif command -v nslookup >/dev/null 2>&1; then
  ip="$(nslookup "$FQDN" 2>/dev/null | awk '/^Address: /{print $2}' | tail -n1 || true)"
else
  ip="$(python3 -c "import socket,sys;print(socket.gethostbyname(sys.argv[1]))" "$FQDN" 2>/dev/null || true)"
fi

[[ -n "${ip:-}" ]] || { echo "FAIL: could not resolve ${FQDN}"; exit 30; }
echo "Resolved to: ${ip}"

# Private ranges: 10/8, 172.16/12, 192.168/16
if [[ "$ip" =~ ^10\. || "$ip" =~ ^192\.168\. || "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
  echo "PASS: ${FQDN} resolves to a PRIVATE IP (${ip})"
  exit 0
else
  echo "FAIL: ${FQDN} resolved to a NON-private IP (${ip}) — private DNS/link misconfigured"
  exit 30
fi
