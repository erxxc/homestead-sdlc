#!/bin/bash
# Validate the local Parallel Works observability stack without external tools.
set -euo pipefail

send_test=false
if [ "${1:-}" = "--send-test-alert" ]; then
    send_test=true
elif [ "$#" -gt 0 ]; then
    echo "usage: $0 [--send-test-alert]" >&2
    exit 2
fi

python3 - "$send_test" <<'PY'
import datetime
import json
import sys
import time
import urllib.error
import urllib.request


def request(url, payload=None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=10) as response:
        return response.status, response.read()


def check_ready(name, url):
    try:
        status, _ = request(url)
        if status != 200:
            raise RuntimeError(f"HTTP {status}")
        print(f"PASS  {name} ready")
    except Exception as exc:
        print(f"FAIL  {name} ready: {exc}")
        failures.append(name)


failures = []
check_ready("Prometheus", "http://127.0.0.1:9090/-/ready")
check_ready("Alertmanager", "http://127.0.0.1:9093/-/ready")
check_ready("Node Exporter", "http://127.0.0.1:9100/metrics")
check_ready("Homestead exporter", "http://127.0.0.1:9225/metrics")
check_ready("SkyFactory exporter", "http://127.0.0.1:9226/metrics")
check_ready("Grafana", "http://127.0.0.1:3000/api/health")
check_ready("Loki", "http://127.0.0.1:3100/ready")
check_ready("Alloy", "http://127.0.0.1:12345/-/healthy")
check_ready("Cloudflare connector", "http://127.0.0.1:2000/ready")

try:
    _, raw = request("http://127.0.0.1:9090/api/v1/targets")
    data = json.loads(raw)["data"]["activeTargets"]
    expected = {"prometheus": 1, "node": 1, "minecraft": 2, "loki": 1, "alloy": 1, "cloudflared": 1}
    for job, count in expected.items():
        targets = [t for t in data if t.get("labels", {}).get("job") == job]
        healthy = [t for t in targets if t.get("health") == "up"]
        if len(targets) == count and len(healthy) == count:
            print(f"PASS  {job} targets {len(healthy)}/{count} up")
        else:
            print(f"FAIL  {job} targets {len(healthy)}/{count} up ({len(targets)} discovered)")
            failures.append(f"targets:{job}")
except Exception as exc:
    print(f"FAIL  Prometheus target inventory: {exc}")
    failures.append("target inventory")

try:
    _, raw = request("http://127.0.0.1:9090/api/v1/rules?type=alert")
    groups = json.loads(raw)["data"]["groups"]
    rules = [rule for group in groups for rule in group.get("rules", [])]
    unhealthy = [rule for rule in rules if rule.get("health") != "ok"]
    if len(rules) >= 10 and not unhealthy:
        print(f"PASS  Prometheus alert rules {len(rules)} loaded and healthy")
    else:
        print(f"FAIL  Prometheus alert rules loaded={len(rules)} unhealthy={len(unhealthy)}")
        failures.append("alert rules")
except Exception as exc:
    print(f"FAIL  Prometheus alert rules: {exc}")
    failures.append("alert rules")

try:
    _, raw = request("http://127.0.0.1:9090/api/v1/query?query=parallel_works_collector_timestamp_seconds")
    result = json.loads(raw)["data"]["result"]
    age = time.time() - float(result[0]["value"][1]) if result else 10**9
    if age < 180:
        print(f"PASS  operational collector age {age:.0f}s")
    else:
        print(f"FAIL  operational collector age {age:.0f}s")
        failures.append("operational collector")
except Exception as exc:
    print(f"FAIL  operational collector: {exc}")
    failures.append("operational collector")

if failures:
    print("\nRESULT: FAIL (" + ", ".join(failures) + ")")
    raise SystemExit(1)

print("\nRESULT: PASS")

if sys.argv[1] == "true":
    now = datetime.datetime.now(datetime.timezone.utc)
    labels = {
        "alertname": "ParallelWorksEndToEndTest",
        "severity": "warning",
        "instance": "manual-smoke-test",
    }
    annotations = {
        "summary": "Parallel Works test alert",
        "description": "Controlled end-to-end notification test; no service is failing.",
    }
    firing = [{
        "labels": labels,
        "annotations": annotations,
        "startsAt": now.isoformat().replace("+00:00", "Z"),
        "endsAt": (now + datetime.timedelta(minutes=10)).isoformat().replace("+00:00", "Z"),
    }]
    request("http://127.0.0.1:9093/api/v2/alerts", firing)
    print("TEST   firing alert submitted; waiting 40s for group delivery")
    time.sleep(40)
    resolved = [{
        "labels": labels,
        "annotations": annotations,
        "startsAt": now.isoformat().replace("+00:00", "Z"),
        "endsAt": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
    }]
    request("http://127.0.0.1:9093/api/v2/alerts", resolved)
    print("TEST   resolved alert submitted; expect firing and resolved ntfy messages")
PY
