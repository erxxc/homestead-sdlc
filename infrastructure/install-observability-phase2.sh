#!/bin/bash
# Install SLOs, log alerts, restore drills, and the weekly health digest.
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then echo "run as root" >&2; exit 1; fi
ROOT=$(cd "$(dirname "$0")/.." && pwd)

required=(
    monitoring/prometheus/parallel-works-metrics.sh
    monitoring/prometheus/rules/slo.rules.yml
    monitoring/loki/loki.yml
    monitoring/loki/rules/fake/log-alerts.yml
    monitoring/alloy/config.alloy
    monitoring/weekly-health-digest.py
    monitoring/grafana/dashboards/parallel-works-service-levels.json
    security/restore-drill.sh
    infrastructure/systemd/minecraft-restore-drill@.service
    infrastructure/systemd/minecraft-restore-drill@.timer
    infrastructure/systemd/parallel-works-weekly-digest.service
    infrastructure/systemd/parallel-works-weekly-digest.timer
)
for path in "${required[@]}"; do
    test -s "$ROOT/$path" || { echo "missing bundle file: $path" >&2; exit 1; }
done
for command in install systemctl systemd-analyze python3 curl; do
    command -v "$command" >/dev/null || { echo "missing required command: $command" >&2; exit 1; }
done

install -d -o prometheus -g prometheus -m 0755 /opt/prometheus/rules /var/lib/node_exporter/textfile_collector
install -o prometheus -g prometheus -m 0644 "$ROOT/monitoring/prometheus/rules/slo.rules.yml" /opt/prometheus/rules/slo.rules.yml
install -o root -g root -m 0755 "$ROOT/monitoring/prometheus/parallel-works-metrics.sh" /usr/local/bin/parallel-works-metrics

install -d -o loki -g loki -m 0750 /etc/loki /var/lib/loki/rules/fake /var/lib/loki/rules-temp
install -o root -g loki -m 0640 "$ROOT/monitoring/loki/loki.yml" /etc/loki/loki.yml
install -o loki -g loki -m 0640 "$ROOT/monitoring/loki/rules/fake/log-alerts.yml" /var/lib/loki/rules/fake/log-alerts.yml
install -o root -g alloy -m 0640 "$ROOT/monitoring/alloy/config.alloy" /etc/alloy/config.alloy

install -o root -g root -m 0755 "$ROOT/security/restore-drill.sh" /usr/local/sbin/minecraft-restore-drill
install -o root -g root -m 0755 "$ROOT/monitoring/weekly-health-digest.py" /usr/local/sbin/parallel-works-weekly-digest
for unit in minecraft-restore-drill@.service minecraft-restore-drill@.timer parallel-works-weekly-digest.service parallel-works-weekly-digest.timer; do
    install -o root -g root -m 0644 "$ROOT/infrastructure/systemd/$unit" "/etc/systemd/system/$unit"
done

install -d -o root -g grafana -m 0750 /var/lib/grafana/dashboards/parallel-works
for dashboard in "$ROOT"/monitoring/grafana/dashboards/*.json; do
    install -o root -g grafana -m 0640 "$dashboard" "/var/lib/grafana/dashboards/parallel-works/$(basename "$dashboard")"
done

for profile in homestead skyfactory4; do
    metric="/var/lib/node_exporter/textfile_collector/restore_drill_${profile}.prom"
    if [ ! -e "$metric" ]; then
        world=$profile
        [ "$profile" = skyfactory4 ] && world=skyfactory
        printf '# HELP parallel_works_restore_drill_last_success_timestamp_seconds Last successful full backup extraction.\n# TYPE parallel_works_restore_drill_last_success_timestamp_seconds gauge\nparallel_works_restore_drill_last_success_timestamp_seconds{world="%s"} 0\n# HELP parallel_works_restore_drill_last_run_success Whether the latest restore drill succeeded.\n# TYPE parallel_works_restore_drill_last_run_success gauge\nparallel_works_restore_drill_last_run_success{world="%s"} 0\n' "$world" "$world" > "$metric"
        chown prometheus:prometheus "$metric"
        chmod 0644 "$metric"
    fi
done

python3 - "$ROOT/monitoring/weekly-health-digest.py" <<'PY'
import ast
import pathlib
import sys
ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
PY
for dashboard in "$ROOT"/monitoring/grafana/dashboards/*.json; do python3 -m json.tool "$dashboard" >/dev/null; done
systemd-analyze verify \
    /etc/systemd/system/minecraft-restore-drill@.service \
    /etc/systemd/system/minecraft-restore-drill@.timer \
    /etc/systemd/system/parallel-works-weekly-digest.service \
    /etc/systemd/system/parallel-works-weekly-digest.timer
/usr/local/bin/promtool check rules /opt/prometheus/rules/slo.rules.yml
/usr/local/bin/loki -verify-config -config.file=/etc/loki/loki.yml
/usr/bin/alloy validate /etc/alloy/config.alloy

systemctl daemon-reload
systemctl enable --now minecraft-restore-drill@homestead.timer minecraft-restore-drill@skyfactory4.timer parallel-works-weekly-digest.timer
systemctl start parallel-works-metrics.service
systemctl restart prometheus.service loki.service alloy.service grafana-server.service

for url in http://127.0.0.1:9090/-/ready http://127.0.0.1:3100/ready http://127.0.0.1:12345/-/healthy http://127.0.0.1:3000/api/health; do
    curl -fsS --retry 15 --retry-connrefused --retry-delay 2 "$url" >/dev/null
done
echo "observability phase 2 installed; restore drills are scheduled but were not started"
