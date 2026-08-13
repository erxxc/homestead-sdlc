#!/bin/bash
# World-consistent Minecraft backup (control C-021).
# save-off -> save-all flush -> tar to .part -> atomic rename -> save-on.
# Preflights free disk so a full disk fails loudly instead of writing a
# truncated archive (root cause of the 2026-08-13 backup incident).
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/minecraft/backups}"
WORLD_PARENT="${WORLD_PARENT:-/opt/minecraft/homestead}"
MIN_FREE_GIB="${MIN_FREE_GIB:-20}"

rcon() {
    python3 - "$1" <<'PY'
import socket
import struct
import sys


def read_secret():
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
    request_id, _ = struct.unpack("<ii", payload[:8])
    return request_id, payload[8:-2].decode("utf-8", errors="replace")


with socket.create_connection(("localhost", 25575), timeout=10) as conn:
    conn.settimeout(10)
    request(conn, 1, 3, read_secret())
    auth_id, _ = response(conn)
    if auth_id == -1:
        raise RuntimeError("RCON authentication failed")
    request(conn, 2, 2, sys.argv[1])
    _, body = response(conn)
    print(body)
PY
}

# Stale partial archives from crashed runs are reclaimed, never mistaken
# for backups (verify and prune only match *.tar.gz).
find "$BACKUP_DIR" -maxdepth 1 -name 'world-*.tar.gz.part' -mmin +120 -delete 2>/dev/null || true

free_bytes=$(df --output=avail -B1 "$BACKUP_DIR" | tail -1)
if [ "$free_bytes" -lt $(( MIN_FREE_GIB * 1024 * 1024 * 1024 )) ]; then
    echo "FATAL: only $(( free_bytes / 1024 / 1024 / 1024 ))GiB free in $BACKUP_DIR, need ${MIN_FREE_GIB}GiB — refusing to write a truncated archive" >&2
    exit 1
fi

stamp=$(date +%Y%m%d-%H%M%S)
part="$BACKUP_DIR/world-$stamp.tar.gz.part"
final="$BACKUP_DIR/world-$stamp.tar.gz"

restore_save() {
    rcon save-on >/dev/null 2>&1 || echo "WARNING: save-on failed — run 'save-on' via RCON manually" >&2
}

rcon save-off >/dev/null
trap restore_save EXIT
rcon "save-all flush" >/dev/null
sleep 5

# tar exit 1 means "some files changed" — tolerable with saving paused
# (session.lock and similar still get touched); >1 is a real failure.
set +e
tar -czf "$part" -C "$WORLD_PARENT" world
rc=$?
set -e
if [ "$rc" -gt 1 ]; then
    rm -f -- "$part"
    echo "FATAL: tar exited $rc" >&2
    exit "$rc"
fi

mv -- "$part" "$final"
echo "backup complete: $final ($(stat -c%s "$final") bytes)"
