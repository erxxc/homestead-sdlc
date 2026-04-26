#!/bin/bash
LOG="/var/log/minecraft-backup-verify.log"
BACKUP_DIR="/opt/minecraft/backups"
TEMP_DIR="/tmp/minecraft-backup-verify"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

latest=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)

if [ -z "$latest" ]; then
    echo "$TIMESTAMP FAIL no backup files found in $BACKUP_DIR" >> "$LOG"
    exit 1
fi

echo "$TIMESTAMP INFO verifying $latest" >> "$LOG"

mkdir -p "$TEMP_DIR"
tar -xzf "$latest" -C "$TEMP_DIR" world/level.dat 2>/dev/null

if [ -f "$TEMP_DIR/world/level.dat" ]; then
    SIZE=$(stat -c%s "$latest")
    echo "$TIMESTAMP PASS backup verified — $latest (${SIZE} bytes)" >> "$LOG"
    rm -rf "$TEMP_DIR"
    exit 0
else
    echo "$TIMESTAMP FAIL backup corrupt or missing level.dat — $latest" >> "$LOG"
    rm -rf "$TEMP_DIR"
    exit 1
fi
