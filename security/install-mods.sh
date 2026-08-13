#!/bin/bash
# Gated mod installer (OPS-003) — installs one phase of hash-verified jars
# through the R-003 supply-chain controls with boot validation and rollback.
#
#   sudo bash install-mods.sh <staging-dir> <jar> [jar...]
#
# <staging-dir> must contain the jars and a SHA512SUMS manifest covering them.
# Preflight refuses to install unless: hashes match, the running Fabric
# Loader satisfies every jar's declared constraint, no installed mod matches
# a jar's declared "breaks", and Fabric API is present when required.
set -uo pipefail

MODS="${MODS:-/opt/minecraft/homestead/mods}"
SERVER_LOG="${SERVER_LOG:-/opt/minecraft/homestead/logs/latest.log}"
REGEN="${REGEN:-/usr/local/bin/regenerate-checksums}"

[ "$(id -u)" -eq 0 ] || { echo "FATAL: run as root" >&2; exit 1; }
[ "$#" -ge 2 ] || { echo "usage: $0 <staging-dir> <jar> [jar...]" >&2; exit 1; }
STAGING="$1"; shift

echo "=== [1/5] Hash verification"
( cd "$STAGING" && sha512sum -c --ignore-missing SHA512SUMS ) || exit 1
for jar in "$@"; do
    grep -qF "  $jar" "$STAGING/SHA512SUMS" || { echo "FATAL: $jar not covered by SHA512SUMS" >&2; exit 1; }
done

echo "=== [2/5] Compatibility preflight (declared constraints vs live server)"
STAGING="$STAGING" MODS="$MODS" SERVER_LOG="$SERVER_LOG" python3 - "$@" <<'PY'
import json
import os
import re
import sys
import zipfile

staging = os.environ["STAGING"]
mods_dir = os.environ["MODS"]
server_log = os.environ["SERVER_LOG"]

with open(server_log, encoding="utf-8", errors="replace") as f:
    m = re.search(r"Fabric Loader (\d+(?:\.\d+)+)", f.read())
if not m:
    sys.exit("FATAL: could not read Fabric Loader version from " + server_log)
loader = tuple(int(x) for x in m.group(1).split("."))
print(f"live Fabric Loader: {m.group(1)}")

installed = [f.lower() for f in os.listdir(mods_dir)]
has_fabric_api = any(f.startswith("fabric-api") for f in installed)
failures = []

for jar in sys.argv[1:]:
    with zipfile.ZipFile(os.path.join(staging, jar)) as z:
        meta = json.loads(z.read("fabric.mod.json"))
    depends = meta.get("depends", {})
    cons = depends.get("fabricloader")
    if cons:
        req = re.search(r">=\s*(\d+(?:\.\d+)+)", cons)
        if req:
            need = tuple(int(x) for x in req.group(1).split("."))
            if loader < need:
                failures.append(f"{jar}: needs fabricloader {cons}, server has {m.group(1)}")
    if any(d.startswith("fabric-") and d != "fabricloader" for d in depends) and not has_fabric_api:
        failures.append(f"{jar}: requires Fabric API modules but no fabric-api jar installed")
    for broken in list(meta.get("breaks", {})) + list(meta.get("conflicts", {})):
        hits = [f for f in installed if broken.lower() in f]
        if hits:
            failures.append(f"{jar}: declares breaks/conflicts with '{broken}' — installed: {hits}")
    print(f"OK {jar}: depends={depends} breaks={list(meta.get('breaks', {}))}")

if failures:
    print("PREFLIGHT FAILURES:", file=sys.stderr)
    for f in failures:
        print("  " + f, file=sys.stderr)
    sys.exit(1)
PY
[ "$?" -eq 0 ] || exit 1

rcon() {
    RCON_PW="$(grep -m1 '^RCON_PASSWORD=' /etc/minecraft/secrets/rcon | cut -d= -f2-)" python3 - "$1" <<'PY'
import os
import socket
import struct
import sys


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


with socket.create_connection(("localhost", 25575), timeout=5) as conn:
    conn.settimeout(5)
    request(conn, 1, 3, os.environ["RCON_PW"])
    if response(conn) == -1:
        raise RuntimeError("RCON authentication failed")
    request(conn, 2, 2, sys.argv[1])
    response(conn)
PY
}

wait_for_server() {
    for i in $(seq 1 30); do
        sleep 10
        rcon "list" 2>/dev/null && return 0
    done
    return 1
}

echo "=== [3/5] Install + checksum rebaseline"
for jar in "$@"; do
    install -o minecraft -g minecraft -m 0644 "$STAGING/$jar" "$MODS/$jar"
done
bash "$REGEN"

echo "=== [4/5] Announced restart"
players=$(curl -fsS -m5 http://127.0.0.1:5000/status 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["players"]["current"])' 2>/dev/null || echo 0)
if [ "$players" -gt 0 ]; then
    rcon "say [SERVER] Restarting in 2 minutes for mod updates" || true
    sleep 90
    rcon "say [SERVER] Restarting in 30 seconds" || true
    sleep 30
else
    rcon "say [SERVER] Restarting now for mod updates" || true
    sleep 5
fi
rcon "save-all flush" || true
sleep 5
systemctl restart minecraft

echo "=== [5/5] Boot validation"
if wait_for_server; then
    echo "PASS: server up with: $*"
    grep -ciE "mixin apply failed|failed to load|incompatible" "$SERVER_LOG" \
        | xargs -I{} echo "boot-log suspicious lines: {}"
    tail -2 /var/log/minecraft-integrity.log
else
    echo "FAIL: server did not come back — rolling back: $*" >&2
    for jar in "$@"; do rm -f "$MODS/$jar"; done
    bash "$REGEN"
    systemctl restart minecraft
    if wait_for_server; then
        echo "Rollback OK — server up on previous mod set. Investigate before retrying." >&2
    else
        echo "CRITICAL: still down after rollback — journalctl -u minecraft" >&2
    fi
    exit 1
fi
