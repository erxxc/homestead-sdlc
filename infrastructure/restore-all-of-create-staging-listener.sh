#!/bin/bash
# Restore the candidate's loopback-only staging listener after an interrupted promotion.
set -euo pipefail
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "run as root" >&2; exit 1; }
file=/opt/minecraft/releases/all-of-create/2.6/server.properties
[ -f "$file" ] || { echo "All of Create server.properties is missing" >&2; exit 1; }
set_property() {
  local key=$1 value=$2 tmp line found=0
  tmp=$(mktemp "${file}.XXXXXX")
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == "$key="* ]]; then printf '%s=%s\n' "$key" "$value" >>"$tmp"; found=1
    else printf '%s\n' "$line" >>"$tmp"; fi
  done <"$file"
  [ "$found" -eq 1 ] || printf '%s=%s\n' "$key" "$value" >>"$tmp"
  mv -f "$tmp" "$file"
}
set_property server-ip 127.0.0.1
set_property server-port 25567
set_property rcon.port 25577
chown minecraft:minecraft "$file"
chmod 0600 "$file"
echo "All of Create staging listener restored to 127.0.0.1:25567 with RCON 25577"
