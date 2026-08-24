#!/usr/bin/env bash
# OPS-005 — one-time migration of Uptime Kuma from eric's pm2 daemon to a
# hardened systemd unit on Node 22, with OnFailure alerting (OPS-004).
#
# Idempotent: every step checks before it changes, so a partial failure can
# simply be re-run. Needs root. Copy this file and uptime-kuma.service to the
# VPS side by side (the runbook uses /tmp/kuma-migrate/), then in your own
# terminal:
#     sudo bash /tmp/kuma-migrate/migrate-to-systemd.sh
#
# Prerequisite already done on 2026-08-24: /opt/uptime-kuma/data chowned away
# from root, pm2 restarted, pm2 logs flushed. This script re-owns the data
# dir to the dedicated service user, so that earlier chown is superseded.
set -euo pipefail

KUMA_DIR=/opt/uptime-kuma
KUMA_USER=uptime-kuma
KUMA_PORT=3001
PM2_USER=eric
NODE_MAJOR=22
NODE_MIN=20.4.0            # Uptime Kuma 2.x engines floor
UNIT_NAME=uptime-kuma.service
UNIT_SRC="$(cd "$(dirname "$0")" && pwd)/${UNIT_NAME}"
UNIT_DST="/etc/systemd/system/${UNIT_NAME}"
KEYRING=/etc/apt/keyrings/nodesource.gpg
KEY_URL=https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key

step() { printf '\n== %s\n' "$*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }
port_listening() { ss -ltn 2>/dev/null | grep -qE "[:.]${KUMA_PORT} "; }
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }
as_pm2_user() {
    runuser -u "$PM2_USER" -- env HOME="/home/${PM2_USER}" \
        PATH=/usr/local/bin:/usr/bin:/bin "$@"
}
pm2_summary() {
    as_pm2_user pm2 jlist 2>/dev/null | python3 -c '
import json, sys
procs = json.load(sys.stdin)
print(", ".join("%s=%s restarts=%s" % (p["name"], p["pm2_env"]["status"],
      p["pm2_env"]["restart_time"]) for p in procs) or "no processes")
' 2>/dev/null || echo unavailable
}

[ "$(id -u)" -eq 0 ] || die "run with sudo"
[ -f "$UNIT_SRC" ] || die "missing $UNIT_SRC (copy uptime-kuma.service next to this script)"
[ -f "$KUMA_DIR/server/server.js" ] || die "$KUMA_DIR does not look like an Uptime Kuma install"
[ -d "$KUMA_DIR/data" ] || die "$KUMA_DIR/data missing"

step "0. Preflight"
echo "host: $(hostname)  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "node: $(node -v 2>/dev/null || echo none)   npm: $(npm -v 2>/dev/null || echo none)"
echo "data dir owner: $(stat -c '%U:%G %a' "$KUMA_DIR/data")"
if port_listening; then echo "port ${KUMA_PORT}: listening"; else echo "port ${KUMA_PORT}: nothing listening"; fi
if command -v pm2 >/dev/null 2>&1; then
    echo "pm2 (${PM2_USER}): $(pm2_summary)"
else
    echo "pm2: not installed"
fi
systemctl is-active --quiet "$UNIT_NAME" 2>/dev/null && echo "${UNIT_NAME}: already active" || true
df -h / | tail -1

step "1. Node ${NODE_MAJOR}.x from NodeSource (manual keyring + pinned source — no curl|bash)"
if node -v >/dev/null 2>&1 && version_ge "$(node -v | sed 's/^v//')" "$NODE_MIN"; then
    echo "node $(node -v) already satisfies >= ${NODE_MIN}; skipping"
else
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y -q ca-certificates curl gnupg >/dev/null
    install -d -o root -g root -m 0755 /etc/apt/keyrings
    if [ ! -s "$KEYRING" ]; then
        curl -fsSL --max-time 30 "$KEY_URL" | gpg --dearmor --batch --yes -o "$KEYRING"
        chmod 0644 "$KEYRING"
        echo "keyring: $(gpg --no-default-keyring --keyring "$KEYRING" --list-keys --with-colons 2>/dev/null | awk -F: '/^uid/{print $10; exit}')"
    fi
    printf 'deb [signed-by=%s] https://deb.nodesource.com/node_%s.x nodistro main\n' \
        "$KEYRING" "$NODE_MAJOR" > /etc/apt/sources.list.d/nodesource.list
    # Prefer NodeSource over the Ubuntu 18.x package so a plain apt upgrade
    # can never downgrade us.
    printf 'Package: nodejs\nPin: origin deb.nodesource.com\nPin-Priority: 600\n' \
        > /etc/apt/preferences.d/nodesource
    apt-get update -q
    echo "apt plan (Ubuntu npm/libnode-dev are superseded — NodeSource nodejs provides npm):"
    apt-get -s install nodejs | grep -E '^(Inst|Remv)' || true
    apt-get install -y -q -o Dpkg::Options::=--force-confold nodejs
fi
NODE_VER="$(node -v | sed 's/^v//')"
version_ge "$NODE_VER" "$NODE_MIN" || die "node ${NODE_VER} still below ${NODE_MIN}"
echo "node: v${NODE_VER}  npm: $(npm -v)  path: $(command -v node)"
[ "$(command -v node)" = /usr/bin/node ] || die "node is not /usr/bin/node (unit ExecStart expects it)"

echo "checking Kuma's native sqlite binding under the new runtime..."
if ! (cd "$KUMA_DIR" && node -e "require('@louislam/sqlite3')" 2>/dev/null); then
    echo "binding failed to load — rebuilding @louislam/sqlite3"
    (cd "$KUMA_DIR" && npm rebuild @louislam/sqlite3)
    (cd "$KUMA_DIR" && node -e "require('@louislam/sqlite3')") || die "sqlite binding still broken"
fi
echo "sqlite binding OK"

step "2. Dedicated service user + data ownership"
if ! getent passwd "$KUMA_USER" >/dev/null; then
    useradd --system --home-dir "$KUMA_DIR" --no-create-home \
        --shell /usr/sbin/nologin --comment "Uptime Kuma service" "$KUMA_USER"
    echo "created system user ${KUMA_USER}"
else
    echo "user ${KUMA_USER} exists"
fi
# kuma.db holds notification secrets (Discord webhook) — no world-read.
chown -R "${KUMA_USER}:${KUMA_USER}" "$KUMA_DIR/data"
find "$KUMA_DIR/data" -type d -exec chmod 750 {} +
find "$KUMA_DIR/data" -type f -exec chmod 640 {} +
echo "data dir: $(stat -c '%U:%G %a' "$KUMA_DIR/data")"

step "3. Retire the pm2 instance"
if command -v pm2 >/dev/null 2>&1 && [ -d "/home/${PM2_USER}/.pm2" ]; then
    as_pm2_user pm2 delete uptime-kuma >/dev/null 2>&1 && echo "pm2: deleted uptime-kuma" || echo "pm2: uptime-kuma not registered"
    as_pm2_user pm2 save --force >/dev/null 2>&1 || true
    as_pm2_user pm2 kill >/dev/null 2>&1 && echo "pm2: daemon stopped" || true
fi
# Any pm2 startup unit — the admin user's, plus the pm2-root.service left
# behind by the original root-run instance (see the incident timeline).
for unit_path in /etc/systemd/system/pm2-*.service; do
    [ -e "$unit_path" ] || continue
    unit="$(basename "$unit_path")"
    systemctl disable --now "$unit" >/dev/null 2>&1 || true
    rm -f "$unit_path"
    echo "removed ${unit}"
done
rm -rf /root/.pm2
systemctl daemon-reload
for _ in $(seq 1 15); do port_listening || break; sleep 1; done
port_listening && die "something still listens on ${KUMA_PORT}: $(ss -ltnp | grep ":${KUMA_PORT} ")"
echo "port ${KUMA_PORT} free"

step "4. Install and start ${UNIT_NAME}"
install -o root -g root -m 0644 "$UNIT_SRC" "$UNIT_DST"
systemctl daemon-reload
systemctl enable --now "$UNIT_NAME" >/dev/null
for _ in $(seq 1 30); do port_listening && break; sleep 1; done
systemctl is-active --quiet "$UNIT_NAME" || { journalctl -u "$UNIT_NAME" -n 20 --no-pager; die "${UNIT_NAME} not active"; }
port_listening || { journalctl -u "$UNIT_NAME" -n 20 --no-pager; die "${UNIT_NAME} active but not listening on ${KUMA_PORT}"; }
echo "http://localhost:${KUMA_PORT}/ -> $(curl -s -m5 -o /dev/null -w '%{http_code}' "http://localhost:${KUMA_PORT}/")  (302 to /dashboard is healthy)"
systemctl show "$UNIT_NAME" -p ActiveState -p SubState -p MainPID -p User -p OnFailure -p NRestarts --no-pager
echo "--- last journal lines:"
journalctl -u "$UNIT_NAME" -n 8 --no-pager -o short-iso | sed 's/\x1b\[[0-9;]*m//g'

step "5. Remove the global pm2 install"
rm -rf /usr/local/lib/node_modules/pm2 /usr/local/bin/pm2 /usr/local/bin/pm2-dev \
       /usr/local/bin/pm2-docker /usr/local/bin/pm2-runtime
echo "removed /usr/local/lib/node_modules/pm2 and its symlinks"
echo "left in place (user-owned): /home/${PM2_USER}/.pm2 — rm -rf it when convenient"
echo "apt autoremove candidates (NOT run — review first with: apt-get -s autoremove):"
apt-get -s autoremove 2>/dev/null | grep -E '^Remv' | awk '{print "  " $2}' | head -n 40 || true

step "6. Evidence for the 2026-08-24 review (items unreadable without sudo)"
echo "deployed commit: $(cat /opt/minecraft/.homestead-sdlc-deployed-commit 2>/dev/null || echo unreadable)"
echo "--- backups:"; ls -la --time-style=long-iso /opt/minecraft/backups/ 2>&1 | grep -vE '^total'
echo "--- alert dispatches (14d):"
journalctl -u 'minecraft-alert@*' --since '14 days ago' --no-pager -o short-iso 2>/dev/null | tail -n 12 | grep . || echo "  none"
echo "--- fail2ban sshd:"; fail2ban-client status sshd 2>&1 | grep -E 'Currently|Total' || true
echo "--- ufw:"; ufw status numbered 2>&1 | head -n 20
echo "--- reboot-required:"; cat /var/run/reboot-required 2>/dev/null || echo "  none"

step "DONE — verify from the ntfy side with the OPS-004 smoke test when convenient"
