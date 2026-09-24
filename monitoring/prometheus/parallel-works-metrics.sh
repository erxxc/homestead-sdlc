#!/bin/bash
set -euo pipefail

readonly OUT_DIR=/var/lib/node_exporter/textfile_collector
readonly OUT="$OUT_DIR/parallel_works.prom"
install -d -o prometheus -g prometheus -m 0755 "$OUT_DIR"
tmp=$(mktemp "$OUT_DIR/.parallel_works.prom.XXXXXX")
trap 'rm -f "$tmp"' EXIT

metric_service() {
    local service=$1 world=${2:-platform} active=0
    systemctl is-active --quiet "$service" && active=1
    printf 'parallel_works_service_active{service="%s",world="%s"} %d\n' "$service" "$world" "$active" >> "$tmp"
}

metric_backup() {
    local world=$1 latest timestamp=0 size=0 directory
    shift
    latest=$(
        for directory in "$@"; do
            find "$directory" -maxdepth 1 -type f -name '*.tar.gz' -printf '%T@ %s %p\n' 2>/dev/null || true
        done | sort -nr | head -1
    )
    if [ -n "$latest" ]; then
        timestamp=${latest%%.*}
        size=$(printf '%s\n' "$latest" | awk '{print $2}')
    fi
    printf 'parallel_works_backup_latest_timestamp_seconds{world="%s"} %s\n' "$world" "$timestamp" >> "$tmp"
    printf 'parallel_works_backup_latest_size_bytes{world="%s"} %s\n' "$world" "$size" >> "$tmp"
}

printf '# HELP parallel_works_service_active Whether a managed systemd service is active.\n# TYPE parallel_works_service_active gauge\n' > "$tmp"
metric_service minecraft.service homestead
metric_service minecraft-skyfactory4-staging.service skyfactory
metric_service prometheus.service
metric_service alertmanager.service
metric_service node_exporter.service
metric_service minecraft-exporter-homestead.service homestead
metric_service minecraft-exporter-skyfactory.service skyfactory
metric_service grafana-server.service
metric_service uptime-kuma.service
metric_service loki.service
metric_service alloy.service
metric_service cloudflared.service
printf '# HELP parallel_works_backup_latest_timestamp_seconds Modification time of the newest profile backup.\n# TYPE parallel_works_backup_latest_timestamp_seconds gauge\n' >> "$tmp"
metric_backup homestead /opt/minecraft/backups/homestead /opt/minecraft/backups
metric_backup skyfactory /opt/minecraft/backups/skyfactory4
printf '# HELP parallel_works_collector_timestamp_seconds Last successful collector run.\n# TYPE parallel_works_collector_timestamp_seconds gauge\nparallel_works_collector_timestamp_seconds %s\n' "$(date +%s)" >> "$tmp"
chown prometheus:prometheus "$tmp"
chmod 0644 "$tmp"
mv -f "$tmp" "$OUT"
trap - EXIT
