#!/usr/bin/env bash
# One-time failure-alert channel setup (OPS-004). Run in YOUR OWN terminal
# (not through a Claude session — this prints the ntfy topic, which is the
# credential):   sudo bash /tmp/setup-alerts.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "run with sudo" >&2
    exit 1
fi

CONF=/etc/minecraft/secrets/alerts

if [ -s "$CONF" ]; then
    echo "$CONF already exists — refusing to overwrite."
    echo "To rotate: sudo rm $CONF, then re-run this script."
    exit 1
fi

# od reads exactly 10 bytes then exits — no SIGPIPE under pipefail, unlike
# tr </dev/urandom | head, which dies 141 before printing anything
TOPIC="homestead-$(od -vAn -N10 -tx1 /dev/urandom | tr -d ' \n')"

install -d -o root -g root -m 0755 /etc/minecraft/secrets
umask 077
printf 'ALERT_URL=https://ntfy.sh/%s\n' "$TOPIC" > "$CONF"
chown root:root "$CONF"
chmod 600 "$CONF"
echo "Wrote $CONF (600 root:root)."
echo
echo "Subscribe in the ntfy app (or a browser) to topic:"
echo
echo "    $TOPIC"
echo
echo "    https://ntfy.sh/$TOPIC"
echo
echo "Sending test notification..."
curl -fsS --max-time 15 \
    -H "Title: [$(hostname)] alert channel test" \
    -H "Tags: white_check_mark" \
    -d "Failure alerting configured. Monitored units will page here when they enter failed state." \
    "https://ntfy.sh/$TOPIC" >/dev/null
echo "Test sent — it should appear once you subscribe (ntfy keeps recent messages)."
