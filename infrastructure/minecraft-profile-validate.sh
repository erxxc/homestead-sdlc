#!/bin/bash
# Fail closed before systemd launches a selected Minecraft profile.
set -euo pipefail

: "${MC_PROFILE:?MC_PROFILE is required}"
: "${MC_ROOT:?MC_ROOT is required}"
: "${MC_WORLD_PARENT:?MC_WORLD_PARENT is required}"
: "${BACKUP_DIR:?BACKUP_DIR is required}"
: "${RCON_PORT:?RCON_PORT is required}"
: "${MC_SERVER_PORT:?MC_SERVER_PORT is required}"
: "${MC_MAP_MODE:?MC_MAP_MODE is required}"
: "${MC_WHITELIST:=true}"

case "$MC_PROFILE" in
    homestead|skyfactory4) ;;
    *) echo "unsupported profile: $MC_PROFILE" >&2; exit 1 ;;
esac

case "$MC_MAP_MODE" in
    online|offline) ;;
    *) echo "unsupported map mode: $MC_MAP_MODE" >&2; exit 1 ;;
esac

case "$MC_WHITELIST" in
    true|false) ;;
    *) echo "unsupported whitelist setting: $MC_WHITELIST" >&2; exit 1 ;;
esac

test -d "$MC_ROOT"
if [ "${MC_ALLOW_NEW_WORLD:-false}" != "true" ]; then
    test -d "$MC_WORLD_PARENT/world"
fi
test -d "$BACKUP_DIR"
test -f "$MC_ROOT/server.properties"
test "$(stat -c %U "$MC_ROOT")" = minecraft
test "$(stat -c %U "$BACKUP_DIR")" = minecraft

grep -Eq "^server-port=${MC_SERVER_PORT}$" "$MC_ROOT/server.properties"
grep -Eq "^rcon.port=${RCON_PORT}$" "$MC_ROOT/server.properties"
grep -Eq '^online-mode=true$' "$MC_ROOT/server.properties"
grep -Eq "^white-list=${MC_WHITELIST}$" "$MC_ROOT/server.properties"
