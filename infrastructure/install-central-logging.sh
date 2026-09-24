#!/bin/bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then echo "run as root" >&2; exit 1; fi
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LOKI_VERSION=${LOKI_VERSION:-3.7.0}
case "$(dpkg --print-architecture)" in amd64) arch=amd64;; arm64) arch=arm64;; *) echo unsupported architecture >&2; exit 1;; esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends curl ca-certificates gnupg unzip acl
install -d -m 0755 /usr/share/keyrings
curl -fsSL --proto '=https' --tlsv1.2 https://apt.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana.gpg.tmp
install -o root -g root -m 0644 /usr/share/keyrings/grafana.gpg.tmp /usr/share/keyrings/grafana.gpg
rm -f /usr/share/keyrings/grafana.gpg.tmp
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main' > /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y --no-install-recommends alloy

work=$(mktemp -d /tmp/loki-install.XXXXXX)
trap 'rm -rf "$work"' EXIT
base="https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}"
asset="loki-linux-${arch}.zip"
curl -fL --retry 3 --proto '=https' --tlsv1.2 -o "$work/$asset" "$base/$asset"
curl -fL --retry 3 --proto '=https' --tlsv1.2 -o "$work/SHA256SUMS" "$base/SHA256SUMS"
(cd "$work" && grep "  $asset\$" SHA256SUMS | sha256sum -c -)
unzip -q "$work/$asset" -d "$work"
install -o root -g root -m 0755 "$work/loki-linux-${arch}" /usr/local/bin/loki

id loki >/dev/null 2>&1 || useradd --system --home-dir /var/lib/loki --create-home --shell /usr/sbin/nologin loki
install -d -o loki -g loki -m 0750 /var/lib/loki
install -d -o root -g loki -m 0750 /etc/loki
install -o root -g loki -m 0640 "$ROOT/monitoring/loki/loki.yml" /etc/loki/loki.yml
install -o root -g root -m 0644 "$ROOT/infrastructure/systemd/loki.service" /etc/systemd/system/loki.service
install -o root -g alloy -m 0640 "$ROOT/monitoring/alloy/config.alloy" /etc/alloy/config.alloy

usermod -aG adm,systemd-journal alloy
for path in /opt/minecraft/homestead/logs /opt/minecraft/skyfactory4-4.2.4/logs /var/log; do
    test -e "$path" && setfacl -m u:alloy:rx "$path"
done
for path in /opt/minecraft/homestead/logs /opt/minecraft/skyfactory4-4.2.4/logs; do
    test -d "$path" && setfacl -d -m u:alloy:rX "$path"
done
for pattern in /opt/minecraft/homestead/logs/latest.log /opt/minecraft/skyfactory4-4.2.4/logs/latest.log /var/log/minecraft-audit.json /var/log/minecraft-audit-skyfactory.json /var/log/minecraft-backup-verify-homestead.log /var/log/minecraft-backup-verify-skyfactory4.log /var/log/minecraft-backup-prune-homestead.log /var/log/minecraft-backup-prune-skyfactory4.log; do
    test -e "$pattern" && setfacl -m u:alloy:r "$pattern"
done

install -d -o root -g grafana -m 0750 /etc/grafana/provisioning/datasources
install -o root -g grafana -m 0640 "$ROOT/monitoring/grafana/provisioning/datasources/loki.yml" /etc/grafana/provisioning/datasources/parallel-works-loki.yml
install -d -o prometheus -g prometheus -m 0755 /opt/prometheus
install -o prometheus -g prometheus -m 0644 "$ROOT/monitoring/prometheus/prometheus.yml" /opt/prometheus/prometheus.yml

/usr/local/bin/loki -verify-config -config.file=/etc/loki/loki.yml
/usr/bin/alloy validate /etc/alloy/config.alloy
/usr/local/bin/promtool check config /opt/prometheus/prometheus.yml
systemctl daemon-reload
systemctl enable --now loki.service alloy.service
systemctl restart prometheus.service grafana-server.service
curl -fsS --retry 15 --retry-connrefused --retry-delay 2 http://127.0.0.1:3100/ready
curl -fsS --retry 15 --retry-connrefused --retry-delay 2 http://127.0.0.1:12345/-/ready
sleep 5
curl -fsS 'http://127.0.0.1:3100/loki/api/v1/labels' | python3 -c 'import json,sys; assert json.load(sys.stdin)["status"] == "success"'
echo "central logging installed; Loki and Alloy remain loopback-only"
