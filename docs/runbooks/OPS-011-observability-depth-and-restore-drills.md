# OPS-011 — Service levels, log alerts, and restore drills

## Scope

Phase 2 adds profile availability recording rules, player counts from the local
status API, actionable Loki alerts, a monthly full-extraction restore drill,
and a weekly ntfy health digest. No listener is added or published.

The Minecraft exporter exposes player statistics but does not expose server
TPS, MSPT, JVM heap, or current online players. The operational collector gets
online and player-capacity data from the existing loopback status API. Do not
interpret the exporter's Go process metrics as Minecraft JVM metrics.

## Install

Build the phase-2 archive from the local Git checkout, copy it to the VPS, and
extract it under `/tmp`. Then run:

```bash
sudo /tmp/parallel-works-observability-phase2/infrastructure/install-observability-phase2.sh
```

The installer validates Prometheus, Loki, Alloy, Python, and dashboard files
before restarting services. It enables the two monthly restore-drill timers and
the Monday weekly-digest timer, but it does not immediately run a restore drill.

## Validate

```bash
systemctl list-timers 'minecraft-restore-drill@*' parallel-works-weekly-digest.timer
curl -fsS 'http://127.0.0.1:9090/api/v1/query?query=parallel_works_players_online'
curl -fsS 'http://127.0.0.1:9090/api/v1/rules'
sudo systemctl status loki alloy prometheus --no-pager
```

Grafana provisions `Parallel Works Service Levels`. Loki sends log-derived
alerts to the existing loopback Alertmanager, which continues to route only to
ntfy.

## Manual restore drill

The drill never writes into a live profile and never launches Minecraft. It
first scans the complete archive to reject unsafe members and measure its exact
expanded byte size. It requires that size plus a 2 GiB safety margin, extracts
the archive under `/var/tmp`, validates a non-empty `world/level.dat`, publishes
metrics, and deletes the extraction on exit.

Run one profile at a time during a quiet period:

```bash
sudo systemctl start minecraft-restore-drill@homestead.service
sudo journalctl -u minecraft-restore-drill@homestead.service -n 100 --no-pager

sudo systemctl start minecraft-restore-drill@skyfactory4.service
sudo journalctl -u minecraft-restore-drill@skyfactory4.service -n 100 --no-pager
```

A successful extraction proves archive readability and world structure. It
does not prove that a particular future mod or Java upgrade can boot the world;
that remains part of each profile's staging and rollback gate.

## Weekly digest

The digest reads local Prometheus only and uses `ALERT_URL` from the existing
root-owned alerts secret. It reports scrape health, firing alerts, seven-day
profile availability, root free space, connector count, and backup age.

Test it without waiting for Monday:

```bash
sudo systemctl start parallel-works-weekly-digest.service
sudo journalctl -u parallel-works-weekly-digest.service -n 50 --no-pager
```

## Rollback

```bash
sudo systemctl disable --now 'minecraft-restore-drill@homestead.timer' 'minecraft-restore-drill@skyfactory4.timer' parallel-works-weekly-digest.timer
sudo rm -f /opt/prometheus/rules/slo.rules.yml /var/lib/loki/rules/fake/log-alerts.yml
sudo systemctl restart prometheus loki
```

Historical metrics and logs remain subject to the existing bounded retention.
