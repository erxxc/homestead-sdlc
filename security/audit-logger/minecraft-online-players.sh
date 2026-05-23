#!/bin/bash
RESULT=$(python3 - 2>/dev/null <<'PY'
import socket
import struct


def read_secret():
    with open("/etc/minecraft/secrets/rcon", encoding="utf-8") as f:
        return f.read().strip().replace("RCON_PASSWORD=", "")


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
    request_id, _ = struct.unpack("<ii", payload[:8])
    body = payload[8:-2].decode("utf-8", errors="replace")
    return request_id, body


with socket.create_connection(("localhost", 25575), timeout=5) as conn:
    conn.settimeout(5)
    request(conn, 1, 3, read_secret())
    auth_id, _ = response(conn)
    if auth_id == -1:
        raise RuntimeError("RCON authentication failed")
    request(conn, 2, 2, "list")
    _, body = response(conn)
    print(body)
PY
)
COUNT=$(echo "$RESULT" | grep -oP '\d+(?= of a max)' | head -1)
[ -n "$COUNT" ] || COUNT=0
echo "# HELP minecraft_players_online Current online player count"
echo "# TYPE minecraft_players_online gauge"
echo "minecraft_players_online $COUNT" > /var/lib/node_exporter/textfile_collector/minecraft_players.prom
