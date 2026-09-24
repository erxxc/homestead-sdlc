#!/bin/bash
# Collect a sanitized security evidence bundle from an operator workstation.
set -euo pipefail

host=${VPS_HOST:-mc.geigercapital.us}
user=${VPS_USER:-eric}
port=${SSH_PORT:-2222}
stamp=$(date -u +%Y%m%dT%H%M%SZ)
out=${1:-"/tmp/parallel-works-security-evidence-$stamp"}
mkdir -p "$out"
chmod 0700 "$out"

for command in curl gh nmap ssh; do
    command -v "$command" >/dev/null || { echo "missing required command: $command" >&2; exit 1; }
done

nmap -Pn -sT -p 22,80,443,2222,3000,3001,5000,8100,9090,9093,9100,9225,9226,25565,25566,25575,25576 "$host" > "$out/external-tcp.txt"

for name in play api map ops status-admin; do
    case "$name" in
        play) url=https://play.geigercapital.us/ ;;
        api) url=https://api.geigercapital.us/health ;;
        map) url=https://map.geigercapital.us/ ;;
        ops) url=https://ops.geigercapital.us/ ;;
        status-admin) url=https://status-admin.geigercapital.us/ ;;
    esac
    raw=$(mktemp "$out/.headers.XXXXXX")
    curl -sS --max-time 20 -D "$raw" -o /dev/null "$url"
    sed -E \
        -e '/^[Ss]et-[Cc]ookie:/d' \
        -e 's|^[Ll]ocation:.*|location: [redacted]|' \
        "$raw" > "$out/${name}-headers.txt"
    rm -f "$raw"
done

gh run list --limit 25 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url > "$out/github-actions.json"

ssh -p "$port" "$user@$host" 'set -e
echo "captured_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "deployed_commit=$(cat /opt/minecraft/.homestead-sdlc-deployed-commit 2>/dev/null || echo unavailable)"
systemctl is-active minecraft minecraft-skyfactory4-staging minecraft-status-api minecraft-audit minecraft-mod-watcher prometheus alertmanager node_exporter grafana-server uptime-kuma loki alloy cloudflared
systemctl --failed --no-pager
systemctl list-timers --all "minecraft-backup*" "minecraft-restore-drill@*" parallel-works-weekly-digest.timer --no-pager
curl -fsS http://127.0.0.1:9090/api/v1/targets
curl -fsS http://127.0.0.1:9090/api/v1/rules
' > "$out/vps-state.txt"

(cd "$out" && shasum -a 256 ./* > SHA256SUMS)
tar -czf "${out}.tar.gz" -C "$(dirname "$out")" "$(basename "$out")"
echo "evidence directory: $out"
echo "archive: ${out}.tar.gz"
