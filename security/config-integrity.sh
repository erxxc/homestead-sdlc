#!/bin/bash
# Verify an explicit, operator-reviewed set of configuration trees.
set -euo pipefail

action=${1:-verify}
paths_file=/etc/minecraft/integrity/paths
baseline=/etc/minecraft/integrity/config.sha256
log=/var/log/minecraft-integrity.log

log_event() {
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$log" 2>/dev/null || true
}

configured_paths() {
    [ -s "$paths_file" ] || return 0
    sed \
        -e 's/[[:space:]]*#.*$//' \
        -e 's/^[[:space:]]*//' \
        -e 's/[[:space:]]*$//' \
        -e '/^$/d' \
        "$paths_file"
}

snapshot() {
    local path
    while IFS= read -r path; do
        case "$path" in /opt/minecraft/*) ;; *) echo "refusing path outside /opt/minecraft: $path" >&2; return 1;; esac
        [ -e "$path" ] || { echo "configured integrity path missing: $path" >&2; return 1; }
        if [ -L "$path" ] || find "$path" -type l -print -quit | grep -q .; then
            echo "symbolic links are not allowed in integrity paths: $path" >&2
            return 1
        fi
        if [ -f "$path" ]; then
            sha256sum "$path"
        else
            find "$path" -type f -print0 | sort -z | xargs -0 -r sha256sum
        fi
    done < <(configured_paths)
}

if ! configured_paths | grep -q .; then
    echo "config integrity has no reviewed paths; skipping"
    log_event "INFO config integrity has no reviewed paths; skipping"
    exit 0
fi

case "$action" in
    generate)
        [ "${EUID:-$(id -u)}" -eq 0 ] || { echo "generate must run as root" >&2; exit 1; }
        tmp=$(mktemp /etc/minecraft/integrity/.config.sha256.XXXXXX)
        trap 'rm -f "$tmp"' EXIT
        snapshot | sort > "$tmp"
        [ -s "$tmp" ] || { echo "refusing empty integrity baseline" >&2; exit 1; }
        chown root:root "$tmp"
        chmod 0444 "$tmp"
        mv -f "$tmp" "$baseline"
        trap - EXIT
        log_event "PASS config integrity baseline generated"
        ;;
    verify)
        [ -s "$baseline" ] || { echo "configured integrity paths have no baseline" >&2; exit 1; }
        tmp=$(mktemp /tmp/minecraft-config-integrity.XXXXXX)
        trap 'rm -f "$tmp"' EXIT
        snapshot | sort > "$tmp"
        if cmp -s "$baseline" "$tmp"; then
            log_event "PASS config integrity check passed"
        else
            log_event "FAIL config integrity check failed"
            diff -u "$baseline" "$tmp" >&2 || true
            exit 1
        fi
        ;;
    *) echo "usage: $0 {generate|verify}" >&2; exit 2 ;;
esac
