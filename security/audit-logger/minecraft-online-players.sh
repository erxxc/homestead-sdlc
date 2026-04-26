#!/bin/bash
RCON_PASS=$(cat /etc/minecraft/secrets/rcon | cut -d'=' -f2)
RESULT=$(mcrcon -H localhost -P 25575 -p "$RCON_PASS" "list" 2>/dev/null)
COUNT=$(echo "$RESULT" | grep -oP '^\d+' || echo "0")
echo "# HELP minecraft_players_online Current online player count"
echo "# TYPE minecraft_players_online gauge"
echo "minecraft_players_online $COUNT" > /var/lib/node_exporter/textfile_collector/minecraft_players.prom
