#!/bin/bash
# Recover the primary slot from an interrupted post-link switch.
set -euo pipefail
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "run as root" >&2; exit 1; }
target=/opt/minecraft/releases/homestead/2.0.1
[ -d "$target/world" ] && [ -f "$target/.parallel-works-profile.env" ] || { echo "Homestead 2.0.1 release is incomplete" >&2; exit 1; }
systemctl stop minecraft.service 2>/dev/null || true
ln -sfn "$target" /opt/minecraft/slots/mc
ln -sfn /opt/minecraft/slots/mc /opt/minecraft/homestead
cp -a "$target/.parallel-works-profile.env" /etc/minecraft/profiles/homestead.env
/usr/local/bin/minecraft-config-integrity generate
systemctl reset-failed minecraft.service
systemctl start minecraft.service
for _ in $(seq 1 180); do
  if systemctl is-active --quiet minecraft.service && timeout 1 bash -c '</dev/tcp/127.0.0.1/25565' 2>/dev/null; then
    echo "RESULT: PASS"
    echo "mc -> $(readlink -f /opt/minecraft/slots/mc)"
    exit 0
  fi
  systemctl is-failed --quiet minecraft.service && break
  sleep 5
done
systemctl status minecraft.service --no-pager -l || true
exit 1
