#!/bin/bash
# Size-capped retention for Minecraft world backups (control C-021).
# Walks backups newest-first: always keeps the MIN_KEEP newest, then keeps
# files while the running total stays under CAP_GIB; everything older than
# the first file that breaks the cap is deleted.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/minecraft/backups}"
CAP_GIB="${CAP_GIB:-50}"
MIN_KEEP="${MIN_KEEP:-2}"
LOG="${LOG:-/var/log/minecraft-backup-prune.log}"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "$(ts) $1" | tee -a "$LOG"; }

if [ ! -d "$BACKUP_DIR" ]; then
    log "FAIL backup dir $BACKUP_DIR missing"
    exit 1
fi

cap_bytes=$(( CAP_GIB * 1024 * 1024 * 1024 ))
total=0 kept=0 deleted=0 freed=0 over=0

while IFS= read -r -d '' entry; do
    file="${entry#* }"
    size=$(stat -c%s "$file")
    if [ "$kept" -lt "$MIN_KEEP" ]; then
        total=$(( total + size )); kept=$(( kept + 1 ))
    elif [ "$over" -eq 0 ] && [ $(( total + size )) -le "$cap_bytes" ]; then
        total=$(( total + size )); kept=$(( kept + 1 ))
    else
        over=1
        rm -f -- "$file"
        deleted=$(( deleted + 1 )); freed=$(( freed + size ))
        log "DELETE $file ($size bytes)"
    fi
done < <(find "$BACKUP_DIR" -maxdepth 1 -name 'world-*.tar.gz' -printf '%T@ %p\0' | sort -znr)

log "OK kept=$kept (${total} bytes) deleted=$deleted (freed ${freed} bytes) cap=${CAP_GIB}GiB min_keep=${MIN_KEEP}"
