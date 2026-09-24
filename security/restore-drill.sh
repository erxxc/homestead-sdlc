#!/bin/bash
# Fully extract the newest backup into a disposable directory and validate it.
set -euo pipefail

profile=${1:-}
case "$profile" in
    homestead)
        world=homestead
        directories=(/opt/minecraft/backups/homestead /opt/minecraft/backups)
        ;;
    skyfactory4)
        world=skyfactory
        directories=(/opt/minecraft/backups/skyfactory4)
        ;;
    *) echo "usage: $0 {homestead|skyfactory4}" >&2; exit 2 ;;
esac

log="/var/log/minecraft-restore-drill-${profile}.log"
metric="/var/lib/node_exporter/textfile_collector/restore_drill_${profile}.prom"
work=$(mktemp -d "/var/tmp/minecraft-restore-${profile}.XXXXXX")
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

write_metric() {
    local success=$1 archive_size=${2:-0} file_count=${3:-0} last_success=0
    if [ "$success" = 1 ]; then
        last_success=$(date +%s)
    elif [ -s "$metric" ]; then
        last_success=$(awk '/^parallel_works_restore_drill_last_success_timestamp_seconds/ {print $2}' "$metric" | tail -1)
        last_success=${last_success:-0}
    fi
    local tmp
    tmp=$(mktemp "${metric}.XXXXXX")
    {
        echo '# HELP parallel_works_restore_drill_last_success_timestamp_seconds Last successful full backup extraction.'
        echo '# TYPE parallel_works_restore_drill_last_success_timestamp_seconds gauge'
        printf 'parallel_works_restore_drill_last_success_timestamp_seconds{world="%s"} %s\n' "$world" "$last_success"
        echo '# HELP parallel_works_restore_drill_last_run_success Whether the latest restore drill succeeded.'
        echo '# TYPE parallel_works_restore_drill_last_run_success gauge'
        printf 'parallel_works_restore_drill_last_run_success{world="%s"} %s\n' "$world" "$success"
        echo '# HELP parallel_works_restore_drill_archive_size_bytes Compressed size of the archive used by the last successful drill.'
        echo '# TYPE parallel_works_restore_drill_archive_size_bytes gauge'
        printf 'parallel_works_restore_drill_archive_size_bytes{world="%s"} %s\n' "$world" "$archive_size"
        echo '# HELP parallel_works_restore_drill_files Extracted file count from the last successful drill.'
        echo '# TYPE parallel_works_restore_drill_files gauge'
        printf 'parallel_works_restore_drill_files{world="%s"} %s\n' "$world" "$file_count"
    } > "$tmp"
    chown prometheus:prometheus "$tmp"
    chmod 0644 "$tmp"
    mv -f "$tmp" "$metric"
}

unexpected_failure() {
    local rc=$?
    trap - ERR
    write_metric 0 "${archive_size:-0}" 0 || true
    printf '%s FAIL restore drill stopped unexpectedly with exit %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc" | tee -a "$log"
    exit "$rc"
}
trap unexpected_failure ERR

latest=$(
    for directory in "${directories[@]}"; do
        find "$directory" -maxdepth 1 -type f -name '*.tar.gz' -printf '%T@ %p\n' 2>/dev/null || true
    done | sort -nr | head -1 | cut -d' ' -f2-
)
if [ -z "$latest" ]; then
    printf '%s FAIL no backup found for %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$profile" | tee -a "$log"
    write_metric 0
    exit 1
fi

archive_size=$(stat -c%s "$latest")
printf '%s INFO validating archive paths and measuring expanded size for %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$latest" | tee -a "$log"
expanded_size=$(python3 - "$latest" <<'PY'
import pathlib
import sys
import tarfile

expanded = 0
with tarfile.open(sys.argv[1], "r|gz") as archive:
    for member in archive:
        path = pathlib.PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"unsafe archive path: {member.name}")
        if not (member.isfile() or member.isdir()):
            raise SystemExit(f"unsupported archive member: {member.name}")
        if member.isfile():
            expanded += member.size
print(expanded)
PY
)
free_bytes=$(df --output=avail -B1 /var/tmp | tail -1)
required=$((expanded_size + 2 * 1024 * 1024 * 1024))
if [ "$free_bytes" -lt "$required" ]; then
    printf '%s FAIL insufficient scratch space: expanded archive is %s bytes, need %s bytes including safety margin, have %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$expanded_size" "$required" "$free_bytes" | tee -a "$log"
    write_metric 0 "$archive_size"
    exit 1
fi

printf '%s INFO extracting %s bytes to disposable storage\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$expanded_size" | tee -a "$log"
tar -xzf "$latest" -C "$work"
level_dat=$(find "$work" -type f -path '*/world/level.dat' -print -quit)
if [ -z "$level_dat" ] || [ ! -s "$level_dat" ]; then
    printf '%s FAIL restored archive has no non-empty world/level.dat\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$log"
    write_metric 0 "$archive_size"
    exit 1
fi
file_count=$(find "$work" -type f | wc -l)
write_metric 1 "$archive_size" "$file_count"
printf '%s PASS %s fully restored and validated (%s files, %s bytes compressed)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$profile" "$file_count" "$archive_size" | tee -a "$log"
