#!/bin/bash
# Atomically select the BlueMap proxy or the intentional offline vhost.
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "run as root" >&2
    exit 1
fi

mode="${1:-}"
case "$mode" in
    online|offline) ;;
    *) echo "usage: $0 {online|offline}" >&2; exit 2 ;;
esac

enabled=/etc/nginx/sites-enabled/bluemap
target="/etc/nginx/sites-available/bluemap-${mode}"
previous=$(readlink -f "$enabled")
tmp="${enabled}.new"

test -f "$target"
ln -sfn "$target" "$tmp"
mv -Tf "$tmp" "$enabled"

if nginx -t; then
    systemctl reload nginx
    echo "map mode: $mode"
    exit 0
fi

echo "invalid map configuration; restoring previous vhost" >&2
ln -sfn "$previous" "$tmp"
mv -Tf "$tmp" "$enabled"
nginx -t
systemctl reload nginx
exit 1
