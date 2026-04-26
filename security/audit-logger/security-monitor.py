#!/usr/bin/env python3
"""
Homestead SMP Security Audit Logger
Watches Minecraft server logs and extracts security-relevant events
to a structured JSON audit trail.
"""

import re
import json
import time
import os
from datetime import datetime, timezone

LOG_FILE = "/opt/minecraft/homestead/logs/latest.log"
AUDIT_LOG = "/var/log/minecraft-audit.json"
STATE_FILE = "/var/lib/minecraft-audit.pos"

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


def get_position():
    try:
        with open(STATE_FILE) as f:
            return int(f.read().strip())
    except:
        return 0


def save_position(pos):
    with open(STATE_FILE, "w") as f:
        f.write(str(pos))


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


def tail_log():
    pos = get_position()
    while True:
        try:
            with open(LOG_FILE) as f:
                f.seek(pos)
                for line in f:
                    process_line(line)
                pos = f.tell()
                save_position(pos)
        except FileNotFoundError:
            pos = 0
            save_position(0)
        time.sleep(5)


if __name__ == "__main__":
    print(f"Starting Homestead audit logger")
    print(f"Watching: {LOG_FILE}")
    print(f"Writing to: {AUDIT_LOG}")
    tail_log()
