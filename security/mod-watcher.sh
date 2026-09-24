#!/bin/bash
LOG="/var/log/minecraft-integrity.log"
WATCH_PATHS=("/opt/minecraft/homestead/mods")

if [ -r /etc/minecraft/integrity/paths ]; then
    while IFS= read -r path; do
        [ -n "$path" ] && [ -e "$path" ] && WATCH_PATHS+=("$path")
    done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' /etc/minecraft/integrity/paths)
fi

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) INFO mod watcher started" >> "$LOG"

inotifywait -m -r -e create,delete,modify,move "${WATCH_PATHS[@]}" --format '%T %e %w%f' --timefmt '%Y-%m-%dT%H:%M:%SZ' |
while read -r TIMESTAMP EVENT FILE; do
    echo "$TIMESTAMP WARN managed file change detected — $EVENT $FILE; manual integrity review required" >> "$LOG"
done
