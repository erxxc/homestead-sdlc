#!/bin/bash
MODS_DIR="/opt/minecraft/homestead/mods"
LOG="/var/log/minecraft-integrity.log"

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) INFO mod watcher started" >> "$LOG"

inotifywait -m -e create,delete,modify,move "$MODS_DIR" --format '%T %e %f' --timefmt '%Y-%m-%dT%H:%M:%SZ' |
while read TIMESTAMP EVENT FILE; do
    if [[ "$FILE" == *.jar ]]; then
        echo "$TIMESTAMP INFO mod change detected — $EVENT $FILE" >> "$LOG"
        sleep 2
        /usr/local/bin/regenerate-checksums
    fi
done
