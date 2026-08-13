#!/bin/bash
# Size-capped retention for Minecraft world backups (control C-021).
# Pass 1: archives under MIN_SIZE_MIB are disk-full truncation garbage
# (2026-08-13 incident left 0B/67M/180M stubs occupying the "newest" slots)
# and are deleted — but only if at least one healthy archive exists.
# Pass 2: walk healthy archives newest-first, always keep the MIN_KEEP
# newest, then keep while the running total stays under CAP_GIB.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/minecraft/backups}"
CAP_GIB="${CAP_GIB:-50}"
MIN_KEEP="${MIN_KEEP:-2}"
MIN_SIZE_MIB="${MIN_SIZE_MIB:-1024}"
LOG="${LOG:-/var/log/minecraft-backup-prune.log}"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "$(ts) $1" | tee -a "$LOG"; }

if [ ! -d "$BACKUP_DIR" ]; then
    log "FAIL backup dir $BACKUP_DIR missing"
    exit 1
fi

cap_bytes=$(( CAP_GIB * 1024 * 1024 * 1024 ))
min_bytes=$(( MIN_SIZE_MIB * 1024 * 1024 ))

healthy=() undersized=()
while IFS= read -r -d '' entry; do
    file="${entry#* }"
    if [ "$(stat -c%s "$file")" -lt "$min_bytes" ]; then
        undersized+=("$file")
    else
        healthy+=("$file")
    fi
done < <(find "$BACKUP_DIR" -maxdepth 1 -name 'world-*.tar.gz' -printf '%T@ %p\0' | sort -znr)

if [ "${#undersized[@]}" -gt 0 ]; then
    if [ "${#healthy[@]}" -gt 0 ]; then
        for file in "${undersized[@]}"; do
            size=$(stat -c%s "$file")
            rm -f -- "$file"
            log "DELETE undersized $file ($size bytes < ${MIN_SIZE_MIB}MiB)"
        done
    else
        log "FAIL all ${#undersized[@]} archives are undersized (<${MIN_SIZE_MIB}MiB) — nothing healthy to keep, refusing to delete; investigate backups NOW"
        exit 1
    fi
fi

total=0 kept=0 deleted=0 freed=0 over=0
for file in ${healthy[@]+"${healthy[@]}"}; do
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
done

log "OK kept=$kept (${total} bytes) deleted=$deleted (freed ${freed} bytes) undersized_removed=${#undersized[@]} cap=${CAP_GIB}GiB min_keep=${MIN_KEEP}"
