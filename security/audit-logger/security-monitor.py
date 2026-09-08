#!/usr/bin/env python3
"""
Homestead SMP Security Audit Logger
Watches Minecraft server logs and extracts security-relevant events
to a structured JSON audit trail.
"""

import json
import os
import re
import time
from datetime import datetime, timezone

LOG_FILE = os.environ.get(
    "MINECRAFT_LOG_FILE", "/opt/minecraft/homestead/logs/latest.log"
)
AUDIT_LOG = os.environ.get("MINECRAFT_AUDIT_LOG", "/var/log/minecraft-audit.json")
STATE_FILE = os.environ.get("MINECRAFT_AUDIT_STATE", "/var/lib/minecraft-audit.pos")

SECURITY_EVENTS = [
    (r"(\w+) joined the game", "PLAYER_JOIN"),
    (r"(\w+) left the game", "PLAYER_LEAVE"),
    (r"Made (\w+) a server operator", "OP_GRANT"),
    (r"(\w+) is no longer a server operator", "OP_REVOKE"),
    (r"Kicked (\w+)", "PLAYER_KICK"),
    (r"Banned player (\w+)", "PLAYER_BAN"),
    (r"Unbanned player (\w+)", "PLAYER_UNBAN"),
    (r"\[RCON\].*?(\w+)", "RCON_COMMAND"),
    (r"Wrong password", "RCON_AUTH_FAIL"),
    (r"FAILED mod integrity check", "INTEGRITY_FAIL"),
    (r"PASS mod integrity check", "INTEGRITY_PASS"),
    (r"(\w+) lost connection", "PLAYER_DISCONNECT"),
    (r"Can't keep up", "SERVER_LAG"),
    (r"Stopping server", "SERVER_STOP"),
    (r"Done \(", "SERVER_START"),
]


def get_state():
    try:
        with open(STATE_FILE) as f:
            value = f.read().strip()
        try:
            state = json.loads(value)
        except json.JSONDecodeError:
            # Backward compatibility with the original integer-only state.
            return {"position": int(value), "device": None, "inode": None}
        return {
            "position": int(state["position"]),
            "device": int(state["device"]),
            "inode": int(state["inode"]),
        }
    except (KeyError, OSError, TypeError, ValueError):
        return {"position": 0, "device": None, "inode": None}


def save_state(state):
    temporary = f"{STATE_FILE}.tmp"
    with open(temporary, "w") as f:
        json.dump(state, f, separators=(",", ":"))
        f.write("\n")
    os.replace(temporary, STATE_FILE)


def write_event(event_type, detail, raw):
    event = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event_type": event_type,
        "detail": detail,
        "raw": raw.strip(),
    }
    with open(AUDIT_LOG, "a") as f:
        f.write(json.dumps(event) + "\n")


def process_line(line):
    for pattern, event_type in SECURITY_EVENTS:
        match = re.search(pattern, line)
        if match:
            write_event(event_type, match.group(0), line)
            return


def read_available(state):
    try:
        with open(LOG_FILE) as f:
            stat = os.fstat(f.fileno())
            replaced = state["device"] is not None and (
                state["device"],
                state["inode"],
            ) != (stat.st_dev, stat.st_ino)
            truncated = stat.st_size < state["position"]
            position = 0 if replaced or truncated else state["position"]

            f.seek(position)
            for line in f:
                process_line(line)

            return {
                "position": f.tell(),
                "device": stat.st_dev,
                "inode": stat.st_ino,
            }
    except FileNotFoundError:
        return {"position": 0, "device": None, "inode": None}


def tail_log():
    state = get_state()
    while True:
        state = read_available(state)
        save_state(state)
        time.sleep(5)


if __name__ == "__main__":
    print(f"Starting Homestead audit logger")
    print(f"Watching: {LOG_FILE}")
    print(f"Writing to: {AUDIT_LOG}")
    tail_log()
