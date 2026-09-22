#!/bin/bash
# Switch between prepared Minecraft profiles with automatic rollback on failure.
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "run as root" >&2
    exit 1
fi

target="${1:-}"
case "$target" in
    homestead|skyfactory4) ;;
    *) echo "usage: $0 {homestead|skyfactory4}" >&2; exit 2 ;;
esac

profile_dir=/etc/minecraft/profiles
active_link=/etc/minecraft/active-profile
target_file="$profile_dir/$target.env"
lock_file=/run/minecraft-profile-switch.lock

exec 9>"$lock_file"
flock -n 9 || { echo "another profile switch is running" >&2; exit 1; }

test -f "$target_file"
test "$(stat -c %U "$target_file")" = root
if [ $(( 8#$(stat -c %a "$target_file") & 8#022 )) -ne 0 ]; then
    echo "$target_file must not be group/world writable" >&2
    exit 1
fi

previous=$(readlink -f "$active_link")
test -n "$previous"
if [ "$previous" = "$target_file" ]; then
    echo "$target is already active"
    exit 0
fi

activate() {
    local file=$1
    local tmp="${active_link}.new"
    ln -sfn "$file" "$tmp"
    mv -Tf "$tmp" "$active_link"
}

start_stack() {
    local active
    local MC_SERVER_PORT
    active=$(readlink -f "$active_link")
    # Profile files are root-owned, mode-checked configuration.
    # shellcheck disable=SC1090
    source "$active"
    systemctl start minecraft
    for _ in $(seq 1 12); do
        if systemctl is-active --quiet minecraft &&
            timeout 1 bash -c "</dev/tcp/127.0.0.1/$MC_SERVER_PORT" 2>/dev/null; then
            break
        fi
        sleep 5
    done
    systemctl is-active --quiet minecraft
    timeout 1 bash -c "</dev/tcp/127.0.0.1/$MC_SERVER_PORT"
    systemctl start minecraft-audit minecraft_exporter minecraft-status-api
    systemctl is-active --quiet minecraft-audit minecraft_exporter minecraft-status-api
}

echo "creating and verifying final backup for $(basename "$previous" .env)"
# Export the current profile so the backup tools select its isolated paths.
set -a
# shellcheck disable=SC1090
source "$previous"
set +a
systemctl start minecraft-backup.service
BACKUP_DIR="$BACKUP_DIR" /usr/local/bin/verify-backup

systemctl stop minecraft-audit minecraft_exporter minecraft-status-api
systemctl stop minecraft

activate "$target_file"
if start_stack; then
    echo "active Minecraft profile: $target"
    exit 0
fi

echo "target failed health checks; restoring $(basename "$previous" .env)" >&2
systemctl stop minecraft-audit minecraft_exporter minecraft-status-api minecraft || true
activate "$previous"
start_stack
exit 1
