#!/bin/bash
RCON_PASS=$(sed 's/^RCON_PASSWORD=//' /etc/minecraft/secrets/rcon)
LOG="/var/log/minecraft-audit.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

announce() {
    mcrcon -H localhost -P 25575 -p "$RCON_PASS" "say $1" 2>/dev/null
}

log_event() {
    echo "{\"timestamp\":\"$TIMESTAMP\",\"event_type\":\"$1\",\"detail\":\"$2\",\"raw\":\"scheduled restart\"}" >> "$LOG"
}

echo "$TIMESTAMP INFO scheduled restart initiated" >> "$LOG"

announce "[SERVER] Restarting in 10 minutes for scheduled maintenance"
sleep 300
announce "[SERVER] Restarting in 5 minutes — please find a safe location"
sleep 240
announce "[SERVER] Restarting in 1 minute"
sleep 50
announce "[SERVER] Restarting now — back in 2 minutes"
sleep 10

log_event "SERVER_STOP" "scheduled restart"

mcrcon -H localhost -P 25575 -p "$RCON_PASS" "save-all flush"
sleep 5

/usr/bin/sudo /usr/bin/systemctl restart minecraft
sleep 30

if /usr/bin/sudo /usr/bin/systemctl is-active --quiet minecraft; then
    log_event "SERVER_START" "scheduled restart complete"
    echo "$TIMESTAMP PASS scheduled restart complete" >> "$LOG"
else
    echo "$TIMESTAMP FAIL server did not restart cleanly" >> "$LOG"
fi
