#!/usr/bin/env python3
"""
Homestead SMP Status API
Exposes safe public-facing server metrics via HTTP endpoint.
Never exposes: player names, system metrics, security events.
"""

from flask import Flask, jsonify
from flask_cors import CORS
import subprocess
import re
import os
from datetime import datetime, timezone

app = Flask(__name__)
CORS(app, origins=["https://play.geigercapital.us", "https://geigercapital.us"])


def get_rcon_password():
    try:
        with open("/etc/minecraft/secrets/rcon") as f:
            content = f.read().strip()
            return content.replace("RCON_PASSWORD=", "")
    except:
        return None


def query_rcon(command):
    password = get_rcon_password()
    if not password:
        return None
    try:
        result = subprocess.run(
            ["mcrcon", "-H", "localhost", "-P", "25575", "-p", password, command],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return result.stdout.strip()
    except:
        return None


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
                "version": "Homestead 1.3.1",
                "minecraft": "1.20.1",
            },
            "map": "http://map.geigercapital.us",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    )


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
