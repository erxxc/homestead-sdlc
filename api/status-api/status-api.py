#!/usr/bin/env python3
"""
Homestead SMP Status API
Exposes safe public-facing server metrics via HTTP endpoint.
Never exposes: player names, system metrics, security events.
"""

from flask import Flask, jsonify
from flask_cors import CORS
import re
import socket
import struct
from datetime import datetime, timezone

app = Flask(__name__)
CORS(app, origins=["https://play.geigercapital.us", "https://geigercapital.us"])


def get_rcon_password():
    # The secrets file is a systemd EnvironmentFile and may hold multiple
    # KEY=VALUE lines (RCON_PASSWORD, MC_RCON_PASSWORD, ...) — parse by line.
    try:
        with open("/etc/minecraft/secrets/rcon") as f:
            for line in f:
                line = line.strip()
                if line.startswith("RCON_PASSWORD="):
                    return line.split("=", 1)[1]
    except OSError:
        return None
    return None


def query_rcon(command):
    password = get_rcon_password()
    if not password:
        return None
    try:
        with socket.create_connection(("localhost", 25575), timeout=5) as conn:
            conn.settimeout(5)
            rcon_request(conn, 1, 3, password)
            auth_id, _, _ = rcon_response(conn)
            if auth_id == -1:
                return None

            rcon_request(conn, 2, 2, command)
            _, _, body = rcon_response(conn)
            return body.strip()
    except (OSError, struct.error, UnicodeDecodeError):
        return None


def rcon_request(conn, request_id, request_type, body):
    payload = struct.pack("<ii", request_id, request_type)
    payload += body.encode("utf-8") + b"\x00\x00"
    conn.sendall(struct.pack("<i", len(payload)) + payload)


def rcon_response(conn):
    length_data = conn.recv(4)
    if len(length_data) != 4:
        raise OSError("short RCON length read")

    (length,) = struct.unpack("<i", length_data)
    payload = b""
    while len(payload) < length:
        chunk = conn.recv(length - len(payload))
        if not chunk:
            raise OSError("short RCON payload read")
        payload += chunk

    request_id, response_type = struct.unpack("<ii", payload[:8])
    body = payload[8:-2].decode("utf-8", errors="replace")
    return request_id, response_type, body


@app.route("/status")
def status():
    # Query player count
    list_result = query_rcon("list")
    player_count = 0
    max_players = 20
    online = False

    if list_result:
        online = True
        match = re.search(r"(\d+) of a max of (\d+)", list_result)
        if match:
            player_count = int(match.group(1))
            max_players = int(match.group(2))

    return jsonify(
        {
            "online": online,
            "players": {"current": player_count, "max": max_players},
            "server": {
                "address": "mc.geigercapital.us",
                "version": "Homestead 1.3.6",
                "minecraft": "1.20.1",
            },
            "map": "https://map.geigercapital.us",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    )


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
