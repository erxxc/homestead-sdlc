#!/bin/bash
# Install a pinned All of Create 2.6 release and its loopback-only staging unit.
set -euo pipefail

[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "run as root" >&2; exit 1; }
[ "${ACCEPT_MINECRAFT_EULA:-}" = TRUE ] || {
  echo "set ACCEPT_MINECRAFT_EULA=TRUE after reviewing https://aka.ms/MinecraftEULA" >&2
  exit 2
}

PACK_URL=https://edge.forgecdn.net/files/9164/660/All_of_Create_v2.6_serverpack.zip
PACK_SHA256=62d50ce36847068ecb40e1653f2f5e3bfedf8c8d4daffbb645055536e21b67d0
NEOFORGE_VERSION=21.1.256
NEOFORGE_URL=https://maven.neoforged.net/releases/net/neoforged/neoforge/${NEOFORGE_VERSION}/neoforge-${NEOFORGE_VERSION}-installer.jar
NEOFORGE_SHA256=4aad931e8fd85fbf6ba35bab647811069d35ff010900492e39db1cb8b017348c
JAVA=/usr/lib/jvm/temurin-21-jdk-amd64/bin/java
CACHE=/var/cache/minecraft
PACK=$CACHE/All_of_Create_v2.6_serverpack.zip
INSTALLER=$CACHE/neoforge-${NEOFORGE_VERSION}-installer.jar
DEST=/opt/minecraft/releases/all-of-create/2.6
STAGE=/opt/minecraft/releases/all-of-create/.2.6.installing.$$
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ROOT_GROUP=$(id -gn root)
committed=false
release_moved=false

cleanup() {
  local rc=$?
  rm -rf "$STAGE"
  if [ "$rc" -ne 0 ] && [ "$release_moved" = true ] && [ "$committed" != true ]; then
    rm -rf "$DEST"
    rm -f /etc/minecraft/profiles/all-of-create-staging.env /etc/systemd/system/minecraft-all-of-create-staging.service
    systemctl daemon-reload 2>/dev/null || true
  fi
  exit "$rc"
}
trap cleanup EXIT
die() { echo "ERROR: $*" >&2; exit 1; }
fetch_verified() {
  local url=$1 sha=$2 path=$3
  if ! printf '%s  %s\n' "$sha" "$path" | sha256sum -c --status 2>/dev/null; then
    curl --fail --location --proto '=https' --tlsv1.2 --output "$path.part" "$url"
    printf '%s  %s\n' "$sha" "$path.part" | sha256sum -c -
    mv -f "$path.part" "$path"
  fi
}
set_property() {
  local file=$1 key=$2 value=$3 tmp line found=0
  tmp=$(mktemp "${file}.XXXXXX")
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == "$key="* ]]; then printf '%s=%s\n' "$key" "$value" >>"$tmp"; found=1
    else printf '%s\n' "$line" >>"$tmp"; fi
  done <"$file"
  [ "$found" -eq 1 ] || printf '%s=%s\n' "$key" "$value" >>"$tmp"
  mv -f "$tmp" "$file"
}

id minecraft >/dev/null 2>&1 || die "minecraft account is missing"
[ -x "$JAVA" ] || die "Temurin Java 21 is missing at $JAVA"
command -v curl >/dev/null && command -v unzip >/dev/null && command -v sha256sum >/dev/null || die "curl, unzip, and coreutils are required"
[ ! -e "$DEST" ] || die "$DEST already exists; refusing to overwrite a release"
avail_kb=$(df -Pk /opt/minecraft | awk 'NR==2{print $4}')
[ "$avail_kb" -ge 10485760 ] || die "at least 10 GiB free is required for install, first world, and backup headroom"

install -d -o root -g "$ROOT_GROUP" -m 0755 "$CACHE" /opt/minecraft/releases/all-of-create
fetch_verified "$PACK_URL" "$PACK_SHA256" "$PACK"
fetch_verified "$NEOFORGE_URL" "$NEOFORGE_SHA256" "$INSTALLER"

if unzip -Z1 "$PACK" | awk 'BEGIN{bad=0} /^\//{bad=1} /\\/{bad=1} {n=split($0,a,"/");for(i=1;i<=n;i++)if(a[i]=="..")bad=1} END{exit bad?0:1}'; then
  die "server pack contains an unsafe archive path"
fi
unzip -tq "$PACK" >/dev/null
install -d -o minecraft -g minecraft -m 0750 "$STAGE"
unzip -q "$PACK" -d "$STAGE"
chown -R minecraft:minecraft "$STAGE"

# Preserve upstream bootstrap files for provenance, but keep their dynamic
# downloader and curl-to-shell path out of the executable runtime.
install -d -o root -g "$ROOT_GROUP" -m 0750 "$STAGE/.upstream-bootstrap"
for file in start.sh start.ps1 start.bat install_java.sh install_java.ps1 variables.txt HOW-TO-RUN.md server-setup-config.yaml manifest.json; do
  [ ! -e "$STAGE/$file" ] || mv "$STAGE/$file" "$STAGE/.upstream-bootstrap/$file"
done
chown -R root:"$ROOT_GROUP" "$STAGE/.upstream-bootstrap"
find "$STAGE/.upstream-bootstrap" -type d -exec chmod 0750 {} +
find "$STAGE/.upstream-bootstrap" -type f -exec chmod 0440 {} +

(cd "$STAGE" && runuser -u minecraft -- env HOME=/opt/minecraft "$JAVA" -jar "$INSTALLER" --installServer)
ARGS=libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/unix_args.txt
[ -s "$STAGE/$ARGS" ] || die "NeoForge did not create $ARGS"

printf 'eula=true\n' >"$STAGE/eula.txt"
set_property "$STAGE/server.properties" online-mode true
set_property "$STAGE/server.properties" server-ip 127.0.0.1
set_property "$STAGE/server.properties" server-port 25567
set_property "$STAGE/server.properties" enable-rcon true
set_property "$STAGE/server.properties" rcon.port 25577
set_property "$STAGE/server.properties" rcon.password disabled-until-launch
set_property "$STAGE/server.properties" white-list false
set_property "$STAGE/server.properties" enforce-whitelist true
set_property "$STAGE/server.properties" enable-command-block false
set_property "$STAGE/server.properties" broadcast-rcon-to-ops false
set_property "$STAGE/server.properties" max-players 10
chmod 0600 "$STAGE/server.properties" "$STAGE/eula.txt"

(cd "$STAGE/mods" && find . -maxdepth 1 -type f -name '*.jar' -print0 | sort -z | xargs -0 sha256sum >"$STAGE/mod_checksums.sha256")
printf '%s  %s\n%s  %s\n' "$PACK_SHA256" "All_of_Create_v2.6_serverpack.zip" "$NEOFORGE_SHA256" "neoforge-${NEOFORGE_VERSION}-installer.jar" >"$STAGE/UPSTREAM-SHA256SUMS"
cat >"$STAGE/UPSTREAM-PROVENANCE.txt" <<EOF
Pack: $PACK_URL
Pack SHA-256: $PACK_SHA256
NeoForge: $NEOFORGE_URL
NeoForge SHA-256: $NEOFORGE_SHA256
Installed (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
cat >"$STAGE/.parallel-works-slot" <<'EOF'
mc
EOF
cat >"$STAGE/.parallel-works-profile.env" <<EOF
MC_PROFILE=all-of-create
MC_PACK_NAME="All of Create 2.6"
MC_MINECRAFT_VERSION=1.21.1
MC_ADDRESS=mc.geigercapital.us
MC_ROOT=/opt/minecraft/homestead
MC_WORLD_PARENT=/opt/minecraft/homestead
MC_WORLD_DIR=/opt/minecraft/homestead/world
BACKUP_DIR=/opt/minecraft/backups/homestead
MC_LOG_FILE=/opt/minecraft/homestead/logs/latest.log
RCON_PORT=25575
MC_SERVER_PORT=25565
MC_MAP_MODE=offline
MC_WHITELIST=false
MC_ALLOW_NEW_WORLD=true
MC_JAVA=$JAVA
MC_LAUNCH_MODE=neoforge-args
MC_LOADER_ARGS_FILE=$ARGS
MC_JVM_ARGS="-Xms2G -Xmx5G -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
EOF
chown -R minecraft:minecraft "$STAGE"
chown -R root:"$ROOT_GROUP" "$STAGE/.upstream-bootstrap"
find "$STAGE/.upstream-bootstrap" -type d -exec chmod 0750 {} +
find "$STAGE/.upstream-bootstrap" -type f -exec chmod 0440 {} +
chown root:"$ROOT_GROUP" "$STAGE/.parallel-works-slot" "$STAGE/.parallel-works-profile.env" "$STAGE/UPSTREAM-SHA256SUMS" "$STAGE/UPSTREAM-PROVENANCE.txt" "$STAGE/mod_checksums.sha256"
chmod 0444 "$STAGE/.parallel-works-slot" "$STAGE/.parallel-works-profile.env" "$STAGE/UPSTREAM-SHA256SUMS" "$STAGE/UPSTREAM-PROVENANCE.txt" "$STAGE/mod_checksums.sha256"
mv "$STAGE" "$DEST"
release_moved=true

install -d -o minecraft -g minecraft -m 0750 /opt/minecraft/backups/all-of-create-staging
install -d -o root -g "$ROOT_GROUP" -m 0755 /etc/minecraft/profiles
cat >/etc/minecraft/profiles/all-of-create-staging.env <<EOF
MC_PROFILE=all-of-create
MC_PACK_NAME="All of Create 2.6 staging"
MC_MINECRAFT_VERSION=1.21.1
MC_ADDRESS=127.0.0.1:25567
MC_ROOT=$DEST
MC_WORLD_PARENT=$DEST
MC_WORLD_DIR=$DEST/world
BACKUP_DIR=/opt/minecraft/backups/all-of-create-staging
MC_LOG_FILE=$DEST/logs/latest.log
RCON_PORT=25577
MC_SERVER_PORT=25567
MC_SERVER_IP=127.0.0.1
MC_MAP_MODE=offline
MC_WHITELIST=false
MC_ALLOW_NEW_WORLD=true
MC_JAVA=$JAVA
MC_LAUNCH_MODE=neoforge-args
MC_LOADER_ARGS_FILE=$ARGS
MC_JVM_ARGS="-Xms2G -Xmx5G -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
EOF
chown root:"$ROOT_GROUP" /etc/minecraft/profiles/all-of-create-staging.env
chmod 0640 /etc/minecraft/profiles/all-of-create-staging.env

install -o root -g "$ROOT_GROUP" -m 0755 "$ROOT/infrastructure/minecraft-profile-launch.sh" /usr/local/bin/minecraft-profile-launch
install -o root -g "$ROOT_GROUP" -m 0755 "$ROOT/infrastructure/minecraft-profile-validate.sh" /usr/local/bin/minecraft-profile-validate
install -o root -g "$ROOT_GROUP" -m 0755 "$ROOT/security/verify-profile-mods.sh" /usr/local/bin/verify-profile-mods
install -o root -g "$ROOT_GROUP" -m 0644 "$ROOT/infrastructure/systemd/minecraft-all-of-create-staging.service" /etc/systemd/system/minecraft-all-of-create-staging.service
systemctl daemon-reload
systemd-analyze verify minecraft-all-of-create-staging.service

committed=true
trap - EXIT
echo "RESULT: PASS"
echo "Installed $DEST; staging remains stopped and loopback-only on 127.0.0.1:25567."
echo "Start it with: systemctl start minecraft-all-of-create-staging.service"
