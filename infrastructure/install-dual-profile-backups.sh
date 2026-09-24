#!/bin/bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then echo "run as root" >&2; exit 1; fi
ROOT=$(cd "$(dirname "$0")/.." && pwd)

install -d -o minecraft -g minecraft -m 0750 /opt/minecraft/backups/homestead /opt/minecraft/backups/skyfactory4
if [ ! -f /etc/minecraft/profiles/homestead.env ]; then
    install -o root -g root -m 0644 "$ROOT/infrastructure/profiles/homestead.env.example" /etc/minecraft/profiles/homestead.env
fi
for tool in backup-world verify-backup prune-backups uptime-kuma-backup-heartbeat; do
    case "$tool" in
        backup-world) source=security/backup-world.sh ;;
        verify-backup) source=security/verify-backup.sh ;;
        prune-backups) source=security/prune-backups.sh ;;
        *) source=monitoring/uptime-kuma/backup-heartbeat.sh ;;
    esac
    install -o root -g root -m 0755 "$ROOT/$source" "/usr/local/bin/$tool"
done
for unit in "$ROOT"/infrastructure/systemd/minecraft-backup-{homestead,skyfactory4}.{service,timer} "$ROOT"/infrastructure/systemd/minecraft-backup-{verify,prune}-{homestead,skyfactory4}.{service,timer}; do
    install -o root -g root -m 0644 "$unit" /etc/systemd/system/
done
systemctl disable --now minecraft-backup.timer minecraft-backup-verify.timer minecraft-backup-prune.timer 2>/dev/null || true
systemctl daemon-reload
systemctl enable --now \
    minecraft-backup-homestead.timer minecraft-backup-verify-homestead.timer minecraft-backup-prune-homestead.timer \
    minecraft-backup-skyfactory4.timer minecraft-backup-verify-skyfactory4.timer minecraft-backup-prune-skyfactory4.timer
systemctl list-timers --all 'minecraft-backup-*'
echo "dual-profile backup timers installed; configure the SkyFactory heartbeat before its first verification"
