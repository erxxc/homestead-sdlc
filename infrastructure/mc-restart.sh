#!/bin/bash
LOG="/var/log/minecraft-audit.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

rcon() {
    python3 - "$1" <<'PY'
import socket
import struct
import sys


def read_secret():
    # EnvironmentFile may hold multiple KEY=VALUE lines — parse by line.
    with open("/etc/minecraft/secrets/rcon", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("RCON_PASSWORD="):
                return line.split("=", 1)[1]
    raise RuntimeError("RCON_PASSWORD not found in secrets file")


def request(conn, request_id, request_type, body):
    payload = struct.pack("<ii", request_id, request_type)
    payload += body.encode("utf-8") + b"\x00\x00"
    conn.sendall(struct.pack("<i", len(payload)) + payload)


def response(conn):
    length_data = conn.recv(4)
    if len(length_data) != 4:
        raise RuntimeError("short RCON length read")
    (length,) = struct.unpack("<i", length_data)
    payload = b""
    while len(payload) < length:
        chunk = conn.recv(length - len(payload))
        if not chunk:
            raise RuntimeError("short RCON payload read")
        payload += chunk
    return struct.unpack("<ii", payload[:8])[0]


command = sys.argv[1]
password = read_secret()
with socket.create_connection(("localhost", 25575), timeout=5) as conn:
    conn.settimeout(5)
    request(conn, 1, 3, password)
    if response(conn) == -1:
        raise RuntimeError("RCON authentication failed")
    request(conn, 2, 2, command)
    response(conn)
PY
}

announce() {
    rcon "say $1" 2>/dev/null
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

rcon "save-all flush"
sleep 5

/usr/bin/sudo /usr/bin/systemctl restart minecraft
sleep 30

if /usr/bin/sudo /usr/bin/systemctl is-active --quiet minecraft; then
    log_event "SERVER_START" "scheduled restart complete"
    echo "$TIMESTAMP PASS scheduled restart complete" >> "$LOG"
else
    echo "$TIMESTAMP FAIL server did not restart cleanly" >> "$LOG"
fi
