#!/bin/bash
LOG="/var/log/minecraft-backup-verify.log"
BACKUP_DIR="/opt/minecraft/backups"
TEMP_DIR=$(mktemp -d /tmp/minecraft-backup-verify.XXXXXX)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

latest=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)

if [ -z "$latest" ]; then
    echo "$TIMESTAMP FAIL no backup files found in $BACKUP_DIR" >> "$LOG"
    exit 1
fi

echo "$TIMESTAMP INFO verifying $latest" >> "$LOG"

tar -xzf "$latest" -C "$TEMP_DIR" world/level.dat 2>/dev/null

if [ -f "$TEMP_DIR/world/level.dat" ]; then
    SIZE=$(stat -c%s "$latest")
    echo "$TIMESTAMP PASS backup verified — $latest (${SIZE} bytes)" >> "$LOG"
    exit 0
else
    echo "$TIMESTAMP FAIL backup corrupt or missing level.dat — $latest" >> "$LOG"
    exit 1
fi
