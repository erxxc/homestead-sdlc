# OPS-010 — Central logging with Loki and Alloy

## Scope

Loki stores 14 days of logs locally using TSDB v13 and filesystem storage.
Alloy collects both Minecraft profiles, structured audit events, backup
verification and pruning, Nginx, cloudflared, and the systemd journal. Loki,
Alloy, and their metrics endpoints bind only to loopback.

## Install

Run from a pinned repository checkout:

```bash
sudo ./infrastructure/install-central-logging.sh
```

The installer verifies the Loki release checksum, uses Grafana's signed apt
repository for Alloy, validates all three configurations, provisions the Loki
Grafana data source, grants Alloy narrow read ACLs, and performs readiness
checks. Minecraft log-directory default ACLs cover newly rotated files.

## Validate

```bash
sudo systemctl status loki alloy --no-pager
curl -fsS http://127.0.0.1:3100/ready
curl -fsS http://127.0.0.1:12345/-/healthy
curl -fsS http://127.0.0.1:3100/loki/api/v1/labels
sudo journalctl -u loki -u alloy --since '10 minutes ago' --no-pager
```

Grafana provisions the `Parallel Works Logs` data source and the `Parallel
Works Logs` dashboard. Use its service, error, Minecraft, audit, and backup
panels for routine investigation; use Explore with `{job=~".+"}` for ad hoc
queries.

## Monitoring enhancements

After central logging is installed, apply the smaller idempotent metrics and
dashboard update without reinstalling Loki or Alloy:

```bash
sudo ./infrastructure/install-monitoring-enhancements.sh
./monitoring/verify-observability.sh
```

This adds the loopback cloudflared metrics target, predictive disk capacity,
Prometheus rule-evaluation, tunnel health, and Loki health alerts. It also
refreshes the operational systemd collector and both provisioned dashboards.

## Capacity and security

Retention is 336 hours, ingestion is limited to 2 MB/s with a 4 MB burst, and
Loki has a 1 GB memory ceiling. Existing host disk alerts remain the hard
capacity guard because filesystem-backed Loki retention is time-based. No Loki
or Alloy port is published through Nginx, Cloudflare Tunnel, UFW, or the
provider firewall.

## Rollback

```bash
sudo systemctl disable --now alloy loki
sudo rm -f /etc/grafana/provisioning/datasources/parallel-works-loki.yml
sudo systemctl restart grafana-server
```

Preserve `/var/lib/loki` until the logs are no longer required. Removing that
directory permanently deletes the centralized log history.
