#!/bin/bash
# Apply narrow systemd sandboxes to custom services with automatic rollback.
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then echo "run as root" >&2; exit 1; fi
ROOT=$(cd "$(dirname "$0")/.." && pwd)
services=(minecraft-status-api minecraft-audit minecraft-mod-watcher)
work=$(mktemp -d /tmp/parallel-works-hardening.XXXXXX)
committed=false

rollback() {
    local rc=$?
    if [ "$committed" != true ]; then
        for service in "${services[@]}"; do
            rm -f "/etc/systemd/system/${service}.service.d/security-hardening.conf"
            if [ -f "$work/${service}.conf" ]; then
                install -o root -g root -m 0644 "$work/${service}.conf" "/etc/systemd/system/${service}.service.d/security-hardening.conf"
            fi
        done
        rm -f /etc/systemd/system/minecraft.service.d/config-integrity.conf
        if [ -f "$work/config-integrity.conf" ]; then
            install -o root -g root -m 0644 "$work/config-integrity.conf" /etc/systemd/system/minecraft.service.d/config-integrity.conf
        fi
        systemctl daemon-reload
        systemctl restart "${services[@]}" || true
        echo "hardening validation failed; previous drop-ins restored" >&2
    fi
    rm -rf "$work"
    exit "$rc"
}
trap rollback EXIT

touch /var/log/minecraft-audit.json /var/log/minecraft-integrity.log
chown minecraft:minecraft /var/log/minecraft-audit.json /var/log/minecraft-integrity.log
chmod 0640 /var/log/minecraft-audit.json /var/log/minecraft-integrity.log

for service in "${services[@]}"; do
    source="$ROOT/infrastructure/systemd/hardening/${service}.conf"
    test -s "$source" || { echo "missing $source" >&2; exit 1; }
    directory="/etc/systemd/system/${service}.service.d"
    install -d -o root -g root -m 0755 "$directory"
    existing="$directory/security-hardening.conf"
    [ ! -f "$existing" ] || cp -a "$existing" "$work/${service}.conf"
    install -o root -g root -m 0644 "$source" "$existing"
done

install -o root -g root -m 0755 "$ROOT/security/config-integrity.sh" /usr/local/bin/minecraft-config-integrity
install -o root -g root -m 0755 "$ROOT/security/mod-watcher.sh" /usr/local/bin/mod-watcher
install -d -o root -g root -m 0755 /etc/minecraft/integrity /etc/systemd/system/minecraft.service.d
[ ! -f /etc/systemd/system/minecraft.service.d/config-integrity.conf ] || cp -a /etc/systemd/system/minecraft.service.d/config-integrity.conf "$work/config-integrity.conf"
install -o root -g root -m 0644 "$ROOT/infrastructure/systemd/config-integrity.conf" /etc/systemd/system/minecraft.service.d/config-integrity.conf

systemctl daemon-reload
for service in "${services[@]}"; do systemd-analyze verify "${service}.service"; done
systemctl restart "${services[@]}"

for service in "${services[@]}"; do systemctl is-active --quiet "$service"; done
curl -fsS --retry 10 --retry-connrefused --retry-delay 1 http://127.0.0.1:5000/health >/dev/null
sleep 6
test -s /var/lib/minecraft-audit/position.json

committed=true
echo "custom-service hardening installed and health-validated"
