#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-/tmp/parallel-works-observability.tar.gz}
tar -czf "$OUT" -C "$ROOT" \
    infrastructure/install-observability-phase1.sh \
    infrastructure/systemd/prometheus.service \
    infrastructure/systemd/alertmanager.service \
    infrastructure/systemd/minecraft-exporter-homestead.service \
    infrastructure/systemd/minecraft-exporter-skyfactory.service \
    infrastructure/systemd/parallel-works-metrics.service \
    infrastructure/systemd/parallel-works-metrics.timer \
    monitoring/prometheus/prometheus.yml \
    monitoring/prometheus/rules/parallel-works.rules.yml \
    monitoring/prometheus/parallel-works-metrics.sh \
    monitoring/alertmanager/alertmanager.yml \
    monitoring/grafana/provisioning/datasources/prometheus.yml \
    monitoring/grafana/provisioning/dashboards/parallel-works.yml \
    monitoring/grafana/dashboards/parallel-works-overview.json
echo "$OUT"
