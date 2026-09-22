#!/bin/bash
# Read-only verification for the isolated SkyFactory 4 installation.
set -euo pipefail

readonly DEST=/opt/minecraft/skyfactory4-4.2.4
readonly ARCHIVE=/var/cache/minecraft/SkyFactory-4_Server_4_2_4.zip
readonly PACK_SHA256=72b1bae61cbd6a07ab55d71f9e1a94239a4992f35a7f9f4a149e4f1eea04a16b
readonly JAVA=/usr/lib/jvm/temurin-8-jdk-amd64/bin/java

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "run as root" >&2
    exit 1
fi

test -x "$JAVA"
"$JAVA" -version 2>&1 | head -1
printf '%s  %s\n' "$PACK_SHA256" "$ARCHIVE" | sha256sum -c -

test -f "$DEST/.homestead-sdlc-skyfactory4-installed"
test -f "$DEST/forge-1.12.2-14.23.5.2860.jar"
test -f "$DEST/eula.txt"
test -f "$DEST/server.properties"
test -s "$DEST/mod_checksums.sha256"
test "$(stat -c %U:%G "$DEST")" = minecraft:minecraft
test "$(stat -c %a "$DEST/server.properties")" = 600

grep -Eq '^server-ip=0\.0\.0\.0$' "$DEST/server.properties"
grep -Eq '^server-port=25566$' "$DEST/server.properties"
grep -Eq '^enable-rcon=true$' "$DEST/server.properties"
grep -Eq '^rcon.port=25576$' "$DEST/server.properties"
grep -Eq '^online-mode=true$' "$DEST/server.properties"
grep -Eq '^white-list=false$' "$DEST/server.properties"
grep -Fq 'Topography-Preset' "$DEST/server.properties"
grep -Eq '^eula=true$' "$DEST/eula.txt"

test "$(systemctl is-active minecraft)" = active
test "$(systemctl show minecraft -p WorkingDirectory --value)" = /opt/minecraft/homestead

echo "PASS: SkyFactory 4 is staged and Homestead remains active"
