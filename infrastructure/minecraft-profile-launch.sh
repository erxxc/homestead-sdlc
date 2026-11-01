#!/bin/bash
# Launch a Minecraft runtime from its systemd EnvironmentFile profile.
set -euo pipefail

: "${MC_ROOT:?MC_ROOT is required}"
: "${MC_JAVA:?MC_JAVA is required}"
: "${MC_JVM_ARGS:?MC_JVM_ARGS is required}"
: "${MC_LAUNCH_MODE:=jar}"

test -d "$MC_ROOT"
test -x "$MC_JAVA"

set_property() {
    local key=$1 value=$2 file=$MC_ROOT/server.properties tmp line found=0
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]]
    tmp=$(mktemp "$MC_ROOT/.server.properties.XXXXXX")
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == "$key="* ]]; then
            printf '%s=%s\n' "$key" "$value" >>"$tmp"
            found=1
        else
            printf '%s\n' "$line" >>"$tmp"
        fi
    done <"$file"
    [ "$found" -eq 1 ] || printf '%s=%s\n' "$key" "$value" >>"$tmp"
    chmod 0600 "$tmp"
    mv -f "$tmp" "$file"
}

# Profiles may select a game listener without affecting RCON. The properties
# file remains mode 0600 and owned by the unprivileged minecraft account.
if [ -n "${MC_SERVER_IP+x}" ]; then
    set_property server-ip "$MC_SERVER_IP"
fi
[ -z "${RCON_PASSWORD:-}" ] || set_property rcon.password "$RCON_PASSWORD"

cd "$MC_ROOT"
read -r -a jvm_args <<< "$MC_JVM_ARGS"
case "$MC_LAUNCH_MODE" in
    jar)
        : "${MC_JAR:?MC_JAR is required for jar launch mode}"
        exec "$MC_JAVA" "${jvm_args[@]}" -jar "$MC_JAR" nogui
        ;;
    neoforge-args)
        : "${MC_LOADER_ARGS_FILE:?MC_LOADER_ARGS_FILE is required for NeoForge}"
        exec "$MC_JAVA" "${jvm_args[@]}" "@$MC_LOADER_ARGS_FILE" nogui
        ;;
    *) echo "unsupported launch mode: $MC_LAUNCH_MODE" >&2; exit 1 ;;
esac
