#!/usr/bin/env bash
# Sends a failure alert for a systemd unit via ntfy. Invoked by
# minecraft-alert@.service through OnFailure=minecraft-alert@%p.service —
# the instance (%i) is the failed unit's name without the .service suffix.
#
# Channel config lives in /etc/minecraft/secrets/alerts (600 root:root),
# one line: ALERT_URL=https://ntfy.sh/<topic>. The topic is the credential:
# never pass it on a command line or print it.
set -euo pipefail

UNIT="${1:?usage: notify-failure <unit-prefix>}"
CONF=/etc/minecraft/secrets/alerts

ALERT_URL=""
while IFS= read -r line; do
    case "$line" in
        ALERT_URL=*) ALERT_URL="${line#ALERT_URL=}" ;;
    esac
done < "$CONF"

if [ -z "$ALERT_URL" ]; then
    echo "no ALERT_URL in $CONF — alert for $UNIT.service NOT sent" >&2
    exit 1
fi

HOST=$(hostname)
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STATE=$(systemctl show "$UNIT.service" -p Result -p ExecMainStatus -p ActiveEnterTimestamp --no-pager 2>/dev/null || true)
JOURNAL=$(journalctl -u "$UNIT.service" -n 10 --no-pager -o short-iso 2>/dev/null | tail -10 || true)

BODY="host: $HOST
unit: $UNIT.service
time: $NOW
$STATE

last journal lines:
$JOURNAL"

curl -fsS --max-time 15 --retry 3 --retry-delay 5 \
    -H "Title: [$HOST] $UNIT.service FAILED" \
    -H "Priority: high" \
    -H "Tags: rotating_light" \
    --data-binary "$BODY" \
    "$ALERT_URL" >/dev/null
