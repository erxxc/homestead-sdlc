#!/bin/bash
set -euo pipefail

readonly DEST=/etc/minecraft/secrets/uptime-kuma-backup-push-url
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "run as root: sudo $0" >&2
    exit 1
fi

install -d -o root -g minecraft -m 0750 /etc/minecraft/secrets
tmp=$(mktemp /etc/minecraft/secrets/.uptime-kuma-backup-push-url.XXXXXX)
trap 'rm -f "$tmp"' EXIT
chmod 0600 "$tmp"
cat > "$tmp"
python3 - "$tmp" <<'PY'
import sys
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

path = Path(sys.argv[1])
parsed = urlsplit(path.read_text(encoding="utf-8").strip())
if parsed.scheme not in {"http", "https"} or not parsed.path.startswith("/api/push/"):
    raise SystemExit("input is not an Uptime Kuma push-monitor URL")
local = urlunsplit(("http", "127.0.0.1:3001", parsed.path, parsed.query, ""))
path.write_text(local + "\n", encoding="utf-8")
PY
chown root:minecraft "$tmp"
chmod 0640 "$tmp"
mv -f "$tmp" "$DEST"
trap - EXIT
echo "backup heartbeat URL stored for the local Kuma listener"
