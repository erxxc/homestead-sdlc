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
: "${MC_LAUNCH_MODE:=jar}"
: "${RCON_PASSWORD:?RCON_PASSWORD is required when RCON is enabled}"

case "$MC_PROFILE" in
    homestead|skyfactory4|all-of-create) ;;
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
test -x "${MC_JAVA:?MC_JAVA is required}"
root_real=$(realpath -e "$MC_ROOT")
world_real=$(realpath -e "$MC_WORLD_PARENT")
backup_real=$(realpath -e "$BACKUP_DIR")
case "$root_real" in /opt/minecraft/*) ;; *) echo "MC_ROOT is outside /opt/minecraft" >&2; exit 1 ;; esac
case "$world_real" in /opt/minecraft/*) ;; *) echo "MC_WORLD_PARENT is outside /opt/minecraft" >&2; exit 1 ;; esac
case "$backup_real" in /opt/minecraft/*) ;; *) echo "BACKUP_DIR is outside /opt/minecraft" >&2; exit 1 ;; esac
case "$(realpath -e "$MC_JAVA")" in /usr/lib/jvm/*/bin/java) ;; *) echo "MC_JAVA is outside the managed JDK paths" >&2; exit 1 ;; esac
if [ "${MC_ALLOW_NEW_WORLD:-false}" != "true" ]; then
    test -d "$MC_WORLD_PARENT/world"
fi
test -d "$BACKUP_DIR"
test -f "$MC_ROOT/server.properties"
test $((8#$(stat -Lc %a "$MC_ROOT/server.properties") & 8#077)) -eq 0
# Compatibility paths may be root-owned symlinks into the release store.
# Validate the resolved directory owner rather than the link owner.
test "$(stat -Lc %U "$MC_ROOT")" = minecraft
test "$(stat -Lc %U "$BACKUP_DIR")" = minecraft

[[ "$MC_SERVER_PORT" =~ ^[0-9]+$ && "$RCON_PORT" =~ ^[0-9]+$ ]]
grep -Fqx "server-port=${MC_SERVER_PORT}" "$MC_ROOT/server.properties"
grep -Fqx "rcon.port=${RCON_PORT}" "$MC_ROOT/server.properties"
grep -Fqx 'online-mode=true' "$MC_ROOT/server.properties"
grep -Fqx "white-list=${MC_WHITELIST}" "$MC_ROOT/server.properties"
grep -Fqx 'enable-rcon=true' "$MC_ROOT/server.properties"
if [ -n "${MC_SERVER_IP+x}" ]; then
    grep -Fqx "server-ip=${MC_SERVER_IP}" "$MC_ROOT/server.properties"
fi

case "$MC_LAUNCH_MODE" in
    jar)
        : "${MC_JAR:?MC_JAR is required for jar launch mode}"
        case "$MC_JAR" in /*|*..*) echo "invalid MC_JAR" >&2; exit 1 ;; esac
        test -f "$MC_ROOT/$MC_JAR"
        ;;
    neoforge-args)
        : "${MC_LOADER_ARGS_FILE:?MC_LOADER_ARGS_FILE is required for NeoForge}"
        case "$MC_LOADER_ARGS_FILE" in /*|*..*) echo "invalid MC_LOADER_ARGS_FILE" >&2; exit 1 ;; esac
        test -f "$MC_ROOT/$MC_LOADER_ARGS_FILE"
        ;;
    *) echo "unsupported launch mode: $MC_LAUNCH_MODE" >&2; exit 1 ;;
esac
