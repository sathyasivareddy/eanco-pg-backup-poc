# syntax=docker/dockerfile:1
# =============================================================================
# Backup container for PostgreSQL pg_dump over private VNet.
# - PostgreSQL 18 client (pg_dump/pg_restore/psql) - MUST match/exceed the
#   major version of the target PostgreSQL Flexible Server(s). pg_dump refuses
#   to run against a server whose major version is newer than the client.
# - Non-root, read-only root FS friendly (writes only to /tmp)
# - No secrets baked in; credentials fetched at runtime from Key Vault via UAMI
#
# PIN THE BASE IMAGE BY DIGEST FOR DEPLOYMENT. Replace the tag below with a
# digest, e.g.:  FROM alpine@sha256:<digest>
# Do not use floating tags in production.
# =============================================================================

FROM alpine:edge AS base

# OCI labels
LABEL org.opencontainers.image.title="eanco-pg-backup" \
      org.opencontainers.image.description="PostgreSQL pg_dump backup job (private VNet, Managed Identity)" \
      org.opencontainers.image.vendor="WinWire" \
      org.opencontainers.image.licenses="Proprietary" \
      org.opencontainers.image.source="https://github.com/<org>/<repo>"

# Install only required packages, then remove caches.
# postgresql18-client provides pg_dump/pg_restore/psql matching server v18.
# apk upgrade first: alpine:edge base layers can lag behind the live package
# index, causing musl/libc ABI mismatches ("symbol not found") for newly
# installed packages built against the newer index. Upgrading first keeps the
# whole rootfs consistent with what gets installed.
RUN set -eux; \
    apk update; \
    apk upgrade --no-cache; \
    apk add --no-cache \
        postgresql18-client \
        bash \
        curl \
        jq \
        gzip \
        coreutils \
        ca-certificates \
        tzdata; \
    update-ca-certificates; \
    rm -rf /var/cache/apk/*

# Create a non-root user and a writable temp workspace.
RUN set -eux; \
    addgroup -S backup -g 10001; \
    adduser -S backup -G backup -u 10001 -h /home/backup; \
    mkdir -p /work /tmp/backup; \
    chown -R backup:backup /work /tmp/backup

WORKDIR /work

# Copy scripts (owned by non-root, read+exec only).
# Note: --chmod is intentionally not used on COPY because ACR classic tasks
# (az acr build) build without BuildKit. Set permissions with an explicit RUN.
COPY --chown=backup:backup entrypoint.sh backup.sh restore-test.sh health-check.sh /usr/local/bin/
RUN chmod 0555 \
        /usr/local/bin/entrypoint.sh \
        /usr/local/bin/backup.sh \
        /usr/local/bin/restore-test.sh \
        /usr/local/bin/health-check.sh

USER 10001:10001

# Fail fast on missing interpreter; strict shell used inside scripts.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
