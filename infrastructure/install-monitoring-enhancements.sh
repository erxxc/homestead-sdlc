#!/bin/bash
# Apply monitoring configuration and dashboards without reinstalling the stack.
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then echo "run as root" >&2; exit 1; fi
ROOT=$(cd "$(dirname "$0")/.." && pwd)

for command in install systemctl curl python3; do
    command -v "$command" >/dev/null || { echo "missing required command: $command" >&2; exit 1; }
done
for service in prometheus.service node_exporter.service grafana-server.service; do
    systemctl cat "$service" >/dev/null 2>&1 || { echo "missing required service: $service" >&2; exit 1; }
done

install -d -o prometheus -g prometheus -m 0755 /opt/prometheus/rules
install -o prometheus -g prometheus -m 0644 "$ROOT/monitoring/prometheus/prometheus.yml" /opt/prometheus/prometheus.yml
install -o prometheus -g prometheus -m 0644 "$ROOT/monitoring/prometheus/rules/parallel-works.rules.yml" /opt/prometheus/rules/parallel-works.rules.yml
install -o root -g root -m 0755 "$ROOT/monitoring/prometheus/parallel-works-metrics.sh" /usr/local/sbin/parallel-works-metrics
install -o root -g root -m 0644 "$ROOT/infrastructure/systemd/parallel-works-metrics.service" /etc/systemd/system/parallel-works-metrics.service
install -o root -g root -m 0644 "$ROOT/infrastructure/systemd/parallel-works-metrics.timer" /etc/systemd/system/parallel-works-metrics.timer

install -d -o root -g grafana -m 0750 /var/lib/grafana/dashboards/parallel-works
for dashboard in "$ROOT"/monitoring/grafana/dashboards/*.json; do
    install -o root -g grafana -m 0640 "$dashboard" "/var/lib/grafana/dashboards/parallel-works/$(basename "$dashboard")"
done

/usr/local/bin/promtool check config /opt/prometheus/prometheus.yml
/usr/local/bin/promtool check rules /opt/prometheus/rules/parallel-works.rules.yml
python3 -m json.tool "$ROOT/monitoring/grafana/dashboards/parallel-works-overview.json" >/dev/null
python3 -m json.tool "$ROOT/monitoring/grafana/dashboards/parallel-works-logs.json" >/dev/null

systemctl daemon-reload
systemctl enable --now parallel-works-metrics.timer
systemctl start parallel-works-metrics.service
systemctl restart prometheus.service grafana-server.service

curl -fsS --retry 15 --retry-connrefused --retry-delay 2 http://127.0.0.1:9090/-/ready >/dev/null
curl -fsS --retry 15 --retry-connrefused --retry-delay 2 http://127.0.0.1:3000/api/health >/dev/null
metrics=$(mktemp /tmp/cloudflared-metrics.XXXXXX)
trap 'rm -f "$metrics"' EXIT
curl -fsS http://127.0.0.1:2000/metrics -o "$metrics"
grep -q '^cloudflared_tunnel_ha_connections' "$metrics"
echo "monitoring enhancements installed; all metrics listeners remain loopback-only"
