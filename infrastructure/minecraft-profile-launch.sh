#!/bin/bash
# Launch the Minecraft runtime selected by /etc/minecraft/active-profile.
set -euo pipefail

: "${MC_ROOT:?MC_ROOT is required}"
: "${MC_JAVA:?MC_JAVA is required}"
: "${MC_JAR:?MC_JAR is required}"
: "${MC_JVM_ARGS:?MC_JVM_ARGS is required}"

test -d "$MC_ROOT"
test -x "$MC_JAVA"
test -f "$MC_ROOT/$MC_JAR"

# Profiles may select a game listener without affecting RCON. The properties
# file remains mode 0600 and owned by the unprivileged minecraft account.
if [ -n "${MC_SERVER_IP+x}" ]; then
    sed -i "s/^server-ip=.*/server-ip=${MC_SERVER_IP}/" "$MC_ROOT/server.properties"
fi

cd "$MC_ROOT"
read -r -a jvm_args <<< "$MC_JVM_ARGS"
exec "$MC_JAVA" "${jvm_args[@]}" -jar "$MC_JAR" nogui
