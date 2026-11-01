#!/bin/bash
# Promote the validated All of Create release into the primary mc slot.
set -euo pipefail
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "run as root" >&2; exit 1; }

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ROOT_GROUP=$(id -gn root)
TARGET=/opt/minecraft/releases/all-of-create/2.6
ACTIVE_PROFILE=/etc/minecraft/profiles/homestead.env
SERVICE=/etc/systemd/system/minecraft.service
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
ARCHIVE=/opt/minecraft/archive/all-of-create-promotion-$STAMP
GENERIC_INSTALLED=false
SLOT_CHANGED=false
COMMITTED=false
CANDIDATE_PUBLIC_PREPARED=false

die() { echo "ERROR: $*" >&2; exit 1; }
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
set_env() { set_property "$1" "$2" "$3"; }
restore_staging_listener() {
  set_property "$TARGET/server.properties" server-ip 127.0.0.1
  set_property "$TARGET/server.properties" server-port 25567
  set_property "$TARGET/server.properties" rcon.port 25577
  chmod 0600 "$TARGET/server.properties"
  chown minecraft:minecraft "$TARGET/server.properties"
}
wait_primary() {
  local ready=0
  for _ in $(seq 1 180); do
    systemctl is-failed --quiet minecraft.service && break
    if systemctl is-active --quiet minecraft.service \
      && timeout 1 bash -c '</dev/tcp/127.0.0.1/25565' 2>/dev/null \
      && curl -fsS http://127.0.0.1:5000/status 2>/dev/null | grep -q '"online":true'; then
      ready=1
      break
    fi
    sleep 5
  done
  [ "$ready" -eq 1 ]
}
rollback_unit() {
  local rc=$?
  trap - EXIT
  if [ "$rc" -ne 0 ] && [ "$CANDIDATE_PUBLIC_PREPARED" = true ] && [ "$COMMITTED" != true ]; then
    restore_staging_listener
  fi
  if [ "$rc" -ne 0 ] && [ "$SLOT_CHANGED" = true ] && [ "$COMMITTED" != true ]; then
    echo "Post-cutover validation failed; switching mc back to Homestead 2.0.1" >&2
    /usr/local/sbin/minecraft-slot-switch mc homestead/2.0.1 || true
  elif [ "$rc" -ne 0 ] && [ "$GENERIC_INSTALLED" = true ] && [ "$COMMITTED" != true ]; then
    echo "Restoring the pre-promotion Homestead unit and profile" >&2
    systemctl stop minecraft.service 2>/dev/null || true
    cp -a "$ARCHIVE/minecraft.service" "$SERVICE"
    cp -a "$ARCHIVE/homestead.env" "$ACTIVE_PROFILE"
    systemctl daemon-reload
    systemctl start minecraft.service minecraft-exporter-homestead.service minecraft-mod-watcher.service 2>/dev/null || true
  fi
  exit "$rc"
}
trap rollback_unit EXIT

exec 9>/run/minecraft-aoc-promotion.lock
flock -n 9 || die "another Minecraft release operation is running"
[ "$(readlink -f /opt/minecraft/slots/mc)" = /opt/minecraft/releases/homestead/2.0.1 ] || die "mc must still point to Homestead 2.0.1"
[ -d "$TARGET/world" ] && [ -s "$TARGET/world/level.dat" ] || die "validated All of Create world is missing"
[ -f "$TARGET/.parallel-works-profile.env" ] || die "target release metadata is missing"
systemctl is-active --quiet minecraft.service || die "Homestead is not active"
systemctl is-active --quiet minecraft-all-of-create-staging.service || die "All of Create staging is not active"
if ss -ntH state established '( sport = :25565 or sport = :25567 )' | grep -q .; then die "a game client is connected"; fi

install -d -o root -g "$ROOT_GROUP" -m 0700 "$ARCHIVE"
cp -a "$SERVICE" "$ARCHIVE/minecraft.service"
cp -a "$ACTIVE_PROFILE" "$ARCHIVE/homestead.env"
printf '%s\n' "Rollback release: homestead/2.0.1" >"$ARCHIVE/ROLLBACK.txt"
chmod 0600 "$ARCHIVE"/*

echo "Creating and verifying the final pre-cutover Homestead backup"
systemctl start minecraft-backup-homestead.service
systemctl start minecraft-backup-verify-homestead.service

echo "Validating the generic primary service against Homestead"
systemctl stop minecraft-all-of-create-staging.service
chown minecraft:minecraft /opt/minecraft/homestead/server.properties
chmod 0600 /opt/minecraft/homestead/server.properties
set_env "$ACTIVE_PROFILE" MC_LAUNCH_MODE jar
set_env "$ACTIVE_PROFILE" MC_WHITELIST false
for release in /opt/minecraft/releases/homestead/1.3.6 /opt/minecraft/releases/homestead/2.0.1; do
  [ ! -f "$release/.parallel-works-profile.env" ] || {
    set_env "$release/.parallel-works-profile.env" MC_LAUNCH_MODE jar
    set_env "$release/.parallel-works-profile.env" MC_WHITELIST false
    chown root:"$ROOT_GROUP" "$release/.parallel-works-profile.env"
    chmod 0644 "$release/.parallel-works-profile.env"
  }
  # Older release setup made the checksum file minecraft-owned. The generic
  # verifier deliberately requires a root-owned, non-writable baseline so the
  # same account that loads jars cannot approve jar changes.
  if [ -f "$release/mod_checksums.sha256" ]; then
    chown root:"$ROOT_GROUP" "$release/mod_checksums.sha256"
    chmod 0444 "$release/mod_checksums.sha256"
  fi
done
install -o root -g "$ROOT_GROUP" -m 0755 "$ROOT/infrastructure/minecraft-profile-launch.sh" /usr/local/bin/minecraft-profile-launch
install -o root -g "$ROOT_GROUP" -m 0755 "$ROOT/infrastructure/minecraft-profile-validate.sh" /usr/local/bin/minecraft-profile-validate
install -o root -g "$ROOT_GROUP" -m 0755 "$ROOT/infrastructure/minecraft-slot-switch.sh" /usr/local/sbin/minecraft-slot-switch
install -o root -g "$ROOT_GROUP" -m 0755 "$ROOT/security/verify-profile-mods.sh" /usr/local/bin/verify-profile-mods
install -o root -g "$ROOT_GROUP" -m 0755 "$ROOT/security/config-integrity.sh" /usr/local/bin/minecraft-config-integrity
install -o root -g "$ROOT_GROUP" -m 0644 "$ROOT/infrastructure/systemd/minecraft-primary.service" "$SERVICE"
systemctl daemon-reload
systemd-analyze verify minecraft.service
GENERIC_INSTALLED=true
if ! systemctl restart minecraft.service; then
  systemctl status minecraft.service --no-pager -l || true
  journalctl -u minecraft.service -n 80 --no-pager || true
  die "generic primary unit failed its Homestead preflight"
fi
wait_primary || die "generic primary unit did not bring Homestead back"

echo "Preparing the validated candidate for the public mc listener"
set_property "$TARGET/server.properties" server-ip ""
set_property "$TARGET/server.properties" server-port 25565
set_property "$TARGET/server.properties" rcon.port 25575
set_property "$TARGET/server.properties" motd "All of Create 2.6"
chmod 0600 "$TARGET/server.properties"
chown minecraft:minecraft "$TARGET/server.properties"
CANDIDATE_PUBLIC_PREPARED=true

echo "Switching mc to All of Create 2.6"
systemctl reset-failed minecraft-backup-homestead.service 2>/dev/null || true
/usr/local/sbin/minecraft-slot-switch mc all-of-create/2.6
SLOT_CHANGED=true
ready=0
for _ in $(seq 1 180); do
  if grep -q 'Done (' /opt/minecraft/homestead/logs/latest.log 2>/dev/null && timeout 1 bash -c '</dev/tcp/127.0.0.1/25565' 2>/dev/null; then ready=1; break; fi
  systemctl is-failed --quiet minecraft.service && break
  sleep 5
done
[ "$ready" -eq 1 ] || die "All of Create did not finish startup"
systemctl is-active --quiet minecraft.service minecraft-exporter-homestead.service minecraft-mod-watcher.service
for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:5000/status | grep -q '"profile":"all-of-create"'; then api_ok=1; break; fi
  sleep 2
done
[ "${api_ok:-0}" -eq 1 ] || die "status API did not select All of Create"

COMMITTED=true
trap - EXIT
echo "RESULT: PASS"
echo "mc -> $(readlink -f /opt/minecraft/slots/mc)"
echo "Homestead rollback: /usr/local/sbin/minecraft-slot-switch mc homestead/2.0.1"
echo "Pre-promotion state: $ARCHIVE"
df -h /opt/minecraft
