#!/bin/bash
# Prepare the pinned SkyFactory 4 server in an isolated staging directory.
# This script does not stop, replace, or restart the production server.
set -euo pipefail

readonly PACK_VERSION="4.2.4"
readonly PACK_URL="https://edge.forgecdn.net/files/3565/687/SkyFactory-4_Server_4_2_4.zip"
readonly PACK_SHA256="72b1bae61cbd6a07ab55d71f9e1a94239a4992f35a7f9f4a149e4f1eea04a16b"
readonly ARCHIVE="/var/cache/minecraft/SkyFactory-4_Server_4_2_4.zip"
readonly DEST="/opt/minecraft/skyfactory4-${PACK_VERSION}"
readonly BACKUP_DIR="/opt/minecraft/backups/skyfactory4"
readonly JAVA="/usr/lib/jvm/temurin-8-jdk-amd64/bin/java"
readonly INSTALLER="forge-1.12.2-14.23.5.2860-installer.jar"
readonly SERVER_JAR="forge-1.12.2-14.23.5.2860.jar"
readonly MARKER="${DEST}/.homestead-sdlc-skyfactory4-installed"
readonly INSTALLING_MARKER="${DEST}/.homestead-sdlc-skyfactory4-installing"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "run as root" >&2
    exit 1
fi

if [ "${ACCEPT_MINECRAFT_EULA:-}" != "TRUE" ]; then
    echo "EULA acceptance is required." >&2
    echo "Review https://www.minecraft.net/eula then rerun with ACCEPT_MINECRAFT_EULA=TRUE." >&2
    exit 2
fi

if [ -e "$DEST" ] && [ ! -f "$MARKER" ] && [ ! -f "$INSTALLING_MARKER" ]; then
    echo "refusing to modify pre-existing unmarked directory: $DEST" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends temurin-8-jdk curl unzip ca-certificates
test -x "$JAVA"

install -d -o root -g root -m 0755 /var/cache/minecraft
if ! printf '%s  %s\n' "$PACK_SHA256" "$ARCHIVE" | sha256sum -c --status; then
    rm -f -- "$ARCHIVE"
    curl -fL --retry 3 --proto '=https' --tlsv1.2 -o "${ARCHIVE}.part" "$PACK_URL"
    printf '%s  %s\n' "$PACK_SHA256" "${ARCHIVE}.part" | sha256sum -c -
    mv -- "${ARCHIVE}.part" "$ARCHIVE"
fi

# Reject absolute paths and traversal before extracting the archive.
python3 - "$ARCHIVE" <<'PY'
import sys
import zipfile
from pathlib import PurePosixPath

with zipfile.ZipFile(sys.argv[1]) as archive:
    for item in archive.infolist():
        path = PurePosixPath(item.filename)
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"unsafe archive path: {item.filename}")
PY

if [ ! -f "$MARKER" ]; then
    install -d -o minecraft -g minecraft -m 0750 "$DEST" "$BACKUP_DIR"
    touch "$INSTALLING_MARKER"
    chown minecraft:minecraft "$INSTALLING_MARKER"
    runuser -u minecraft -- unzip -q "$ARCHIVE" -d "$DEST"
fi

test -f "$DEST/$INSTALLER"
if [ ! -f "$DEST/$SERVER_JAR" ]; then
    runuser -u minecraft -- bash -c 'cd "$1" && exec "$2" -jar "$3" --installServer' \
        bash "$DEST" "$JAVA" "$INSTALLER"
fi
test -f "$DEST/$SERVER_JAR"

RCON_PASSWORD=$(sed -n 's/^RCON_PASSWORD=//p' /etc/minecraft/secrets/rcon | head -1)
if [ -z "$RCON_PASSWORD" ]; then
    echo "RCON_PASSWORD is missing from /etc/minecraft/secrets/rcon" >&2
    exit 1
fi
export RCON_PASSWORD

python3 - "$DEST/server.properties" <<'PY'
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
values = {}
order = []
for raw in path.read_text(encoding="utf-8").splitlines():
    if not raw or raw.startswith("#") or "=" not in raw:
        continue
    key, value = raw.split("=", 1)
    values[key] = value
    order.append(key)

required = {
    "server-ip": "0.0.0.0",
    "server-port": "25566",
    "enable-rcon": "true",
    "rcon.port": "25576",
    "rcon.password": os.environ["RCON_PASSWORD"],
    "online-mode": "true",
    "white-list": "true",
    "enable-query": "false",
}
values.update(required)
for key in required:
    if key not in order:
        order.append(key)

path.write_text("\n".join(f"{key}={values[key]}" for key in order) + "\n", encoding="utf-8")
PY

printf 'eula=true\n' > "$DEST/eula.txt"
find "$DEST/mods" -maxdepth 1 -type f -name '*.jar' -print0 | sort -z | xargs -0 sha256sum > "$DEST/mod_checksums.sha256"
printf '%s  %s\n' "$PACK_SHA256" "$ARCHIVE" > "$DEST/server-pack.sha256"
printf 'SkyFactory 4 %s installed from CurseForge file 3565687\n' "$PACK_VERSION" > "$MARKER"
rm -f -- "$INSTALLING_MARKER"

chown -R minecraft:minecraft "$DEST" "$BACKUP_DIR"
chmod 0750 "$DEST" "$BACKUP_DIR"
chmod 0600 "$DEST/server.properties" "$DEST/eula.txt"

echo "SkyFactory 4 ${PACK_VERSION} prepared at $DEST"
echo "Staging game listener: 0.0.0.0:25566; RCON remains on its separate protected port 25576"
echo "Production Homestead was not modified or restarted."
