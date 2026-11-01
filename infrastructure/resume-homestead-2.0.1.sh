#!/bin/bash
# Resume the initial 2.0.1 cutover after the release layout was installed.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
OLD=/opt/minecraft/releases/homestead/1.3.6
NEW=/opt/minecraft/releases/homestead/2.0.1
SLOT=/opt/minecraft/slots/mc
COMPAT=/opt/minecraft/homestead
PROFILE=/etc/minecraft/profiles/homestead.env
archive=$(find /opt/minecraft/archive -maxdepth 1 -type d -name 'homestead-pre-2.0-*' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
[ -d "$OLD" ] && [ -d "$NEW" ] && [ -n "$archive" ] || { echo "release migration is incomplete" >&2; exit 1; }
(cd "$archive" && sha256sum -c SHA256SUMS)
systemctl reset-failed minecraft-skyfactory4-staging.service
systemctl start minecraft-skyfactory4-staging.service minecraft-exporter-skyfactory.service
systemctl is-active --quiet minecraft-skyfactory4-staging.service
previous=$(readlink -f "$SLOT")
rollback() {
  rc=$?; trap - EXIT
  if [ "$rc" -ne 0 ]; then
    echo "Resume failed; restoring Homestead 1.3.6" >&2
    systemctl stop minecraft.service 2>/dev/null || true
    ln -sfn "$previous" "$SLOT"; ln -sfn "$SLOT" "$COMPAT"
    cp -a "$OLD/.parallel-works-profile.env" "$PROFILE"
    /usr/local/bin/minecraft-config-integrity generate 2>/dev/null || true
    systemctl start minecraft.service minecraft-exporter-homestead.service minecraft-mod-watcher.service 2>/dev/null || true
  fi
  exit "$rc"
}
trap rollback EXIT
systemctl stop minecraft-exporter-homestead.service minecraft-mod-watcher.service minecraft.service
ln -sfn "$NEW" "$SLOT"; ln -sfn "$SLOT" "$COMPAT"
cp -a "$NEW/.parallel-works-profile.env" "$PROFILE"
/usr/local/bin/minecraft-config-integrity generate
systemctl start minecraft.service
ready=0
for _ in $(seq 1 120); do
  systemctl is-failed --quiet minecraft.service && break
  if [ -s "$COMPAT/world/level.dat" ] && grep -q 'Done (' "$COMPAT/logs/latest.log" 2>/dev/null; then ready=1; break; fi
  sleep 10
done
[ "$ready" -eq 1 ] || { echo "Homestead 2.0.1 did not become ready" >&2; exit 1; }
systemctl start minecraft-exporter-homestead.service minecraft-mod-watcher.service
systemctl is-active --quiet minecraft.service minecraft-exporter-homestead.service minecraft-skyfactory4-staging.service minecraft-exporter-skyfactory.service
trap - EXIT
echo "RESULT: PASS"
echo "mc -> $(readlink -f "$SLOT")"
echo "sb -> $(readlink -f /opt/minecraft/slots/sb)"
df -h /opt/minecraft
