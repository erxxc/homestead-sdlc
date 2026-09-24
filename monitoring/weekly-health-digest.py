#!/usr/bin/env python3
"""Send a compact weekly operational summary to the configured ntfy topic."""
import json
import os
import urllib.parse
import urllib.request

PROMETHEUS = "http://127.0.0.1:9090/api/v1/query?query="


def query(expression, default="n/a"):
    url = PROMETHEUS + urllib.parse.quote(expression, safe="")
    with urllib.request.urlopen(url, timeout=10) as response:
        result = json.load(response)["data"]["result"]
    return result[0]["value"][1] if result else default


def secret_url():
    with open("/etc/minecraft/secrets/alerts", encoding="utf-8") as source:
        for line in source:
            if line.startswith("ALERT_URL="):
                return line.split("=", 1)[1].strip().split("?", 1)[0]
    raise RuntimeError("ALERT_URL missing from /etc/minecraft/secrets/alerts")


values = {
    "targets": query("sum(up)"),
    "targets_total": query("count(up)"),
    "alerts": query('sum(ALERTS{alertstate="firing"}) or vector(0)'),
    "disk": float(
        query(
            '100 * node_filesystem_avail_bytes{mountpoint="/",fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{mountpoint="/",fstype!~"tmpfs|overlay"}',
            "0",
        )
    ),
    "homestead": float(
        query('parallel_works:profile_availability:ratio_7d{world="homestead"}', "0")
    ),
    "skyfactory": float(
        query('parallel_works:profile_availability:ratio_7d{world="skyfactory"}', "0")
    ),
    "connections": query("cloudflared_tunnel_ha_connections", "0"),
    "backup_h": float(
        query(
            'time() - parallel_works_backup_latest_timestamp_seconds{world="homestead"}',
            "0",
        )
    )
    / 3600,
    "backup_s": float(
        query(
            'time() - parallel_works_backup_latest_timestamp_seconds{world="skyfactory"}',
            "0",
        )
    )
    / 3600,
}
message = (
    f"Targets {values['targets']}/{values['targets_total']} · firing alerts {values['alerts']}\n"
    f"7d availability: Homestead {values['homestead']:.3%}, SkyFactory {values['skyfactory']:.3%}\n"
    f"Root free {values['disk']:.1f}% · tunnel connections {values['connections']}\n"
    f"Backup age: Homestead {values['backup_h']:.1f}h, SkyFactory {values['backup_s']:.1f}h"
)
request = urllib.request.Request(secret_url(), data=message.encode(), method="POST")
request.add_header("Title", "Parallel Works weekly health")
request.add_header("Tags", "bar_chart,white_check_mark")
with urllib.request.urlopen(request, timeout=15) as response:
    if response.status >= 300:
        raise RuntimeError(f"ntfy returned HTTP {response.status}")
print(message)
