#!/bin/bash
set -euo pipefail

profile="${MC_PROFILE:-homestead}"
SECRET="/etc/minecraft/secrets/uptime-kuma-backup-push-url-${profile}"
if [ "$profile" = homestead ] && [ ! -s "$SECRET" ]; then
    SECRET=/etc/minecraft/secrets/uptime-kuma-backup-push-url
fi
readonly SECRET
if [ ! -s "$SECRET" ]; then
    echo "INFO backup heartbeat disabled: $SECRET is not configured"
    exit 0
fi

python3 - "$SECRET" <<'PY'
import sys
import urllib.error
import urllib.request

with open(sys.argv[1], encoding="utf-8") as handle:
    url = handle.read().strip()
if not url.startswith("http://127.0.0.1:3001/api/push/"):
    raise SystemExit("backup heartbeat URL must use the local Uptime Kuma listener")
try:
    with urllib.request.urlopen(url, timeout=10) as response:
        if not 200 <= response.status < 300:
            raise RuntimeError(f"HTTP {response.status}")
except (OSError, urllib.error.URLError) as exc:
    raise SystemExit(f"backup heartbeat delivery failed: {exc}") from exc
print("backup verification heartbeat delivered")
PY
