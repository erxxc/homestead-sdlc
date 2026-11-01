#!/bin/bash
# Switch one public slot to a registered release, with backup and rollback.
set -euo pipefail
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "run as root" >&2; exit 1; }
slot=${1:-}; release=${2:-}
case "$slot" in
  mc) service=minecraft.service; exporter=minecraft-exporter-homestead.service; compat=/opt/minecraft/homestead; profile=/etc/minecraft/profiles/homestead.env; backup=minecraft-backup-homestead.service; verify=minecraft-backup-verify-homestead.service; port=25565 ;;
  sb) service=minecraft-skyfactory4-staging.service; exporter=minecraft-exporter-skyfactory.service; compat=/opt/minecraft/skyfactory4-4.2.4; profile=/etc/minecraft/profiles/skyfactory4-staging.env; backup=minecraft-backup-skyfactory4.service; verify=minecraft-backup-verify-skyfactory4.service; port=25566 ;;
  *) echo "usage: $0 {mc|sb} <family/version>" >&2; exit 2 ;;
esac
case "$release" in ''|/*|*..*) echo "release must be a relative family/version" >&2; exit 2 ;; esac
target=/opt/minecraft/releases/$release; slot_link=/opt/minecraft/slots/$slot
metadata=$target/.parallel-works-slot; target_profile=$target/.parallel-works-profile.env
exec 9>/run/minecraft-slot-switch.lock; flock -n 9 || { echo "another slot switch is running" >&2; exit 1; }
[ -d "$target" ] && [ -f "$metadata" ] && [ -f "$target_profile" ] || { echo "release is not registered: $release" >&2; exit 1; }
[ "$(cat "$metadata")" = "$slot" ] || { echo "release is registered for another slot" >&2; exit 1; }
[ "$(stat -c %U "$target_profile")" = root ] || { echo "release profile must be root-owned" >&2; exit 1; }
[ $((8#$(stat -c %a "$target_profile") & 8#022)) -eq 0 ] || { echo "release profile must not be group/world writable" >&2; exit 1; }
current=$(readlink -f "$slot_link"); [ "$current" != "$target" ] || { echo "$slot already uses $release"; exit 0; }; [ -d "$current" ] || { echo "current slot target is invalid" >&2; exit 1; }
old_profile=$(mktemp); cp -a "$profile" "$old_profile"
switched=0; committed=0
profile_id() { sed -n 's/^MC_PROFILE=//p' "$1" | tail -1 | tr -d '"'; }
cleanup() {
  rc=$?; trap - EXIT
  if [ "$rc" -ne 0 ] && [ "$switched" -eq 1 ] && [ "$committed" -eq 0 ]; then
    echo "Switch failed; restoring prior release" >&2
    systemctl stop "$service" 2>/dev/null || true
    ln -sfn "$current" "$slot_link"; ln -sfn "$slot_link" "$compat"; cp -a "$old_profile" "$profile"
    MC_PROFILE=$(profile_id "$old_profile") /usr/local/bin/minecraft-config-integrity generate 2>/dev/null || true
    systemctl start "$service" "$exporter" minecraft-mod-watcher.service 2>/dev/null || true
  fi
  rm -f "$old_profile"
  exit "$rc"
}
trap cleanup EXIT
echo "Backing up and verifying $slot before switching"; systemctl start "$backup"; systemctl start "$verify"
systemctl stop "$exporter" minecraft-mod-watcher.service 2>/dev/null || true; systemctl stop "$service"
switched=1
ln -sfn "$target" "$slot_link"; ln -sfn "$slot_link" "$compat"; cp -a "$target_profile" "$profile"
MC_PROFILE=$(profile_id "$target_profile") /usr/local/bin/minecraft-config-integrity generate
failed=1; systemctl start "$service" || true
for _ in $(seq 1 120); do systemctl is-failed --quiet "$service" && break; if systemctl is-active --quiet "$service" && timeout 1 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then failed=0; break; fi; sleep 5; done
if [ "$failed" -ne 0 ]; then
  echo "Target failed health checks" >&2
  exit 1
fi
systemctl start "$exporter" minecraft-mod-watcher.service
committed=1
echo "RESULT: PASS"; echo "$slot -> $(readlink -f "$slot_link")"
