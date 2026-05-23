#!/bin/bash
MODS_DIR="/opt/minecraft/homestead/mods"
LOG="/var/log/minecraft-integrity.log"

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) INFO mod watcher started" >> "$LOG"

inotifywait -m -e create,delete,modify,move "$MODS_DIR" --format '%T %e %f' --timefmt '%Y-%m-%dT%H:%M:%SZ' |
while read TIMESTAMP EVENT FILE; do
    if [[ "$FILE" == *.jar ]]; then
        echo "$TIMESTAMP WARN mod change detected — $EVENT $FILE; manual checksum review required" >> "$LOG"
    fi
done
