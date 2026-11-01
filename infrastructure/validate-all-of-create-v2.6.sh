#!/bin/bash
# Exercise two clean All of Create boots, isolation, and a restorable world archive.
set -euo pipefail
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "run as root" >&2; exit 1; }

SERVICE=minecraft-all-of-create-staging.service
SKY=minecraft-skyfactory4-staging.service
ROOT=/opt/minecraft/releases/all-of-create/2.6
BACKUPS=/opt/minecraft/backups/all-of-create-staging
sky_was_active=0
systemctl is-active --quiet "$SKY" && sky_was_active=1

cleanup() {
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    systemctl stop "$SERVICE" 2>/dev/null || true
    [ "$sky_was_active" -eq 0 ] || systemctl start "$SKY" 2>/dev/null || true
  fi
  exit "$rc"
}
trap cleanup EXIT

systemctl is-active --quiet minecraft.service
systemctl stop "$SKY"
for boot in 1 2; do
  echo "TEST clean boot $boot of 2"
  systemctl reset-failed "$SERVICE" 2>/dev/null || true
  systemctl start "$SERVICE"
  ready=0
  for _ in $(seq 1 180); do
    systemctl is-failed --quiet "$SERVICE" && break
    if grep -q 'Done (' "$ROOT/logs/latest.log" 2>/dev/null && timeout 1 bash -c '</dev/tcp/127.0.0.1/25567' 2>/dev/null; then ready=1; break; fi
    sleep 5
  done
  [ "$ready" -eq 1 ] || { journalctl -u "$SERVICE" -n 80 --no-pager; exit 1; }
  systemctl is-active --quiet minecraft.service
  ss -ltnH '( sport = :25567 )' | awk '$4 !~ /^127\.0\.0\.1:25567$/ {bad=1} END{exit bad}'
  [ -s "$ROOT/world/level.dat" ]
  ! grep -Eqi '(^|[^a-z])(fatal|exception in server tick loop|failed to bind)' "$ROOT/logs/latest.log"
  systemctl stop "$SERVICE"
done

stamp=$(date -u +%Y%m%dT%H%M%SZ)
archive=$BACKUPS/world-$stamp.tar.gz
tar -C "$ROOT" -czf "$archive" world
tar -tzf "$archive" | grep -qx 'world/level.dat'
tar -xOf "$archive" world/level.dat >/dev/null
chown minecraft:minecraft "$archive"
chmod 0640 "$archive"

systemctl start "$SERVICE"
echo "RESULT: PASS"
echo "All of Create is running on loopback port 25567; SkyFactory remains stopped."
echo "Validated archive: $archive"
trap - EXIT
