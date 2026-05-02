#!/bin/bash
MODS_DIR="/opt/minecraft/homestead/mods"
CHECKSUM_FILE="/opt/minecraft/homestead/mod_checksums.sha256"
LOG="/var/log/minecraft-integrity.log"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "$TIMESTAMP INFO starting checksum regeneration" >> "$LOG"

sudo chmod 644 "$CHECKSUM_FILE"
sudo chown minecraft:minecraft "$CHECKSUM_FILE"

sha256sum "$MODS_DIR"/*.jar | sort > "$CHECKSUM_FILE"

sudo chmod 444 "$CHECKSUM_FILE"

COUNT=$(wc -l < "$CHECKSUM_FILE")
echo "$TIMESTAMP PASS checksum regeneration complete — $COUNT mods baselined" >> "$LOG"
echo "Checksums regenerated for $COUNT mods"
