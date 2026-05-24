#!/bin/bash
LOG="/var/log/minecraft-backup-verify.log"
BACKUP_DIR="/opt/minecraft/backups"
TEMP_DIR=$(mktemp -d /tmp/minecraft-backup-verify.XXXXXX)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

log() {
    echo "$TIMESTAMP $1" | tee -a "$LOG"
}

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

latest=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)

if [ -z "$latest" ]; then
    log "FAIL no backup files found in $BACKUP_DIR"
    exit 1
fi

log "INFO verifying $latest"

LEVEL_DAT=$(tar -tzf "$latest" 2>/dev/null | grep -E '(^|/)world/level\.dat$' | head -1)

if [ -n "$LEVEL_DAT" ]; then
    tar -xzf "$latest" -C "$TEMP_DIR" "$LEVEL_DAT" 2>/dev/null
    SIZE=$(stat -c%s "$latest")
    log "PASS backup verified — $latest (${SIZE} bytes)"
    exit 0
else
    log "FAIL backup corrupt or missing level.dat — $latest"
    exit 1
fi
