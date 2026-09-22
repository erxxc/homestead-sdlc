#!/bin/bash
# Install the Parallel Works observability baseline from a repository checkout.
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "run as root: sudo $0" >&2
    exit 1
fi

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ALERTMANAGER_VERSION=${ALERTMANAGER_VERSION:-0.28.1}
ARCH=$(dpkg --print-architecture)
case "$ARCH" in
    amd64) AM_ARCH=amd64 ;;
    arm64) AM_ARCH=arm64 ;;
    *) echo "unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

for path in \
    monitoring/prometheus/prometheus.yml \
    monitoring/prometheus/rules/parallel-works.rules.yml \
    monitoring/prometheus/parallel-works-metrics.sh \
    monitoring/alertmanager/alertmanager.yml \
    monitoring/grafana/dashboards/parallel-works-overview.json; do
    test -s "$ROOT/$path" || { echo "missing bundle file: $path" >&2; exit 1; }
done

id prometheus >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin prometheus
install -d -o prometheus -g prometheus -m 0755 /var/lib/prometheus /var/lib/alertmanager /var/lib/node_exporter/textfile_collector
install -d -o root -g root -m 0755 /opt/prometheus/rules /etc/parallel-works
install -d -o root -g grafana -m 0750 /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards
install -d -o grafana -g grafana -m 0755 /var/lib/grafana/dashboards/parallel-works
if [ ! -e /opt/prometheus/prometheus.yml.pre-observability ]; then
    cp -a /opt/prometheus/prometheus.yml /opt/prometheus/prometheus.yml.pre-observability
fi

archive="alertmanager-${ALERTMANAGER_VERSION}.linux-${AM_ARCH}.tar.gz"
work=$(mktemp -d /tmp/parallel-works-observability.XXXXXX)
trap 'rm -rf "$work"' EXIT
if [ ! -x /usr/local/bin/alertmanager ]; then
    base="https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}"
    curl -fL --retry 3 --proto '=https' --tlsv1.2 -o "$work/$archive" "$base/$archive"
    curl -fL --retry 3 --proto '=https' --tlsv1.2 -o "$work/sha256sums.txt" "$base/sha256sums.txt"
    (cd "$work" && grep "  $archive\$" sha256sums.txt | sha256sum -c -)
    tar -xzf "$work/$archive" -C "$work"
    install -o root -g root -m 0755 "$work/alertmanager-${ALERTMANAGER_VERSION}.linux-${AM_ARCH}/alertmanager" /usr/local/bin/alertmanager
    install -o root -g root -m 0755 "$work/alertmanager-${ALERTMANAGER_VERSION}.linux-${AM_ARCH}/amtool" /usr/local/bin/amtool
fi

if [ ! -s /etc/parallel-works/alertmanager-webhook-url ]; then
    alert_url=$(sed -n 's/^ALERT_URL=//p' /etc/minecraft/secrets/alerts 2>/dev/null | head -1 || true)
    if [ -z "$alert_url" ]; then
        echo "ALERT_URL is missing from /etc/minecraft/secrets/alerts" >&2
        exit 1
    fi
    printf '%s\n' "$alert_url" > /etc/parallel-works/alertmanager-webhook-url
    chown prometheus:prometheus /etc/parallel-works/alertmanager-webhook-url
    chmod 0600 /etc/parallel-works/alertmanager-webhook-url
fi

install -o prometheus -g prometheus -m 0644 "$ROOT/monitoring/prometheus/prometheus.yml" /opt/prometheus/prometheus.yml
install -o prometheus -g prometheus -m 0644 "$ROOT/monitoring/prometheus/rules/parallel-works.rules.yml" /opt/prometheus/rules/parallel-works.rules.yml
install -o root -g root -m 0755 "$ROOT/monitoring/prometheus/parallel-works-metrics.sh" /usr/local/bin/parallel-works-metrics
install -o prometheus -g prometheus -m 0640 "$ROOT/monitoring/alertmanager/alertmanager.yml" /etc/parallel-works/alertmanager.yml
install -o root -g root -m 0644 "$ROOT/infrastructure/systemd/prometheus.service" /etc/systemd/system/prometheus.service
install -o root -g root -m 0644 "$ROOT/infrastructure/systemd/alertmanager.service" /etc/systemd/system/alertmanager.service
install -o root -g root -m 0644 "$ROOT/infrastructure/systemd/minecraft-exporter-homestead.service" /etc/systemd/system/minecraft-exporter-homestead.service
install -o root -g root -m 0644 "$ROOT/infrastructure/systemd/minecraft-exporter-skyfactory.service" /etc/systemd/system/minecraft-exporter-skyfactory.service
install -o root -g root -m 0644 "$ROOT/infrastructure/systemd/parallel-works-metrics.service" /etc/systemd/system/parallel-works-metrics.service
install -o root -g root -m 0644 "$ROOT/infrastructure/systemd/parallel-works-metrics.timer" /etc/systemd/system/parallel-works-metrics.timer
install -o root -g grafana -m 0640 "$ROOT/monitoring/grafana/provisioning/datasources/prometheus.yml" /etc/grafana/provisioning/datasources/parallel-works-prometheus.yml
install -o root -g grafana -m 0640 "$ROOT/monitoring/grafana/provisioning/dashboards/parallel-works.yml" /etc/grafana/provisioning/dashboards/parallel-works.yml
install -o grafana -g grafana -m 0644 "$ROOT/monitoring/grafana/dashboards/parallel-works-overview.json" /var/lib/grafana/dashboards/parallel-works/overview.json

/usr/local/bin/amtool check-config /etc/parallel-works/alertmanager.yml
/usr/local/bin/promtool check config /opt/prometheus/prometheus.yml
/usr/local/bin/promtool check rules /opt/prometheus/rules/parallel-works.rules.yml
systemctl daemon-reload
systemctl disable --now minecraft_exporter.service 2>/dev/null || true
systemctl enable --now alertmanager.service minecraft-exporter-homestead.service minecraft-exporter-skyfactory.service parallel-works-metrics.timer
systemctl start parallel-works-metrics.service
systemctl restart prometheus.service grafana-server.service

for url in http://127.0.0.1:9090/-/ready http://127.0.0.1:9093/-/ready http://127.0.0.1:9225/metrics http://127.0.0.1:9226/metrics; do
    curl -fsS --retry 10 --retry-connrefused --retry-delay 2 "$url" >/dev/null
done
test -s /var/lib/node_exporter/textfile_collector/parallel_works.prom
echo "Observability phase 1 installed. Review: systemctl --failed; amtool alert query --alertmanager.url=http://127.0.0.1:9093"
