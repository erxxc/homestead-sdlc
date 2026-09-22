# OPS-009 — Observability and browser-based administration

## Purpose

This baseline adds two-world metrics, actionable alerts, bounded Prometheus
retention, and a provisioned Grafana overview. All services remain bound to
loopback. No monitoring, RCON, or management port is opened to the Internet.

## Install

Build the portable bundle on a trusted workstation:

```bash
./infrastructure/build-observability-bundle.sh
scp -P 2222 /tmp/parallel-works-observability.tar.gz eric@SERVER:/tmp/
```

On the VPS, inspect and run the root-only installer:

```bash
mkdir -p /tmp/parallel-works-observability
tar -xzf /tmp/parallel-works-observability.tar.gz -C /tmp/parallel-works-observability
sudo /tmp/parallel-works-observability/infrastructure/install-observability-phase1.sh
```

The installer downloads Alertmanager 0.28.1 from the official Prometheus
release, verifies the release checksum, replaces the single-world exporter
unit with isolated Homestead and SkyFactory units, and provisions the Grafana
dashboard. Alertmanager's HA gossip listener is disabled for this single-node
deployment, leaving only the loopback HTTP listener. Re-running the installer
is safe. The ntfy receiver URL selects ntfy's built-in `alertmanager` template
so its JSON webhook becomes a readable firing or resolved notification.

## Validate

```bash
./monitoring/verify-observability.sh
./monitoring/verify-observability.sh --send-test-alert
```

The second command sends a controlled alert, waits through Alertmanager's
grouping delay, and resolves it. Expect readable firing and resolved messages
in ntfy. For lower-level investigation:

```bash
sudo systemctl --failed
sudo systemctl status prometheus alertmanager node_exporter \
  minecraft-exporter-homestead minecraft-exporter-skyfactory \
  parallel-works-metrics.timer --no-pager
curl -fsS http://127.0.0.1:9090/api/v1/targets
curl -fsS http://127.0.0.1:9090/api/v1/rules
sudo journalctl -u prometheus --since '24 hours ago' | grep -iE 'wal|corrupt|repair'
```

The last command investigates the previously observed WAL corruption counter.
If it shows only a historical repair and the counter does not increase, retain
the data. If it increases, stop Prometheus and follow the Prometheus storage
recovery procedure before deleting any blocks.

## Browser access without an SSH bridge

Use a Cloudflare Tunnel with Cloudflare Access in front of Grafana and Uptime
Kuma. The tunnel makes outbound connections from the VPS, so ports 3000, 3001,
9090, 9093, 9225, and 9226 remain closed publicly.

Recommended applications:

| Hostname | Local origin | Access policy |
| --- | --- | --- |
| `ops.geigercapital.us` | `http://127.0.0.1:3000` | Named operators, MFA required |
| `status-admin.geigercapital.us` | `http://127.0.0.1:3001` | Named operators, MFA required |

Keep Prometheus and Alertmanager internal. Grafana provides the read path;
Kuma provides focused service checks. Set Access sessions to eight hours or
less and retain Grafana's own login as a second authentication boundary.

Create the tunnel and Access applications in Cloudflare Zero Trust, then use a
remotely-managed tunnel token. Store the token only in root-readable systemd
credentials or Cloudflare's packaged service command; do not commit it.

```bash
sudo cloudflared service install YOUR_ONE_TIME_TUNNEL_TOKEN
sudo systemctl status cloudflared --no-pager
```

The existing GitHub Actions workflow is the preferred non-SSH control plane
for deploys and service operations. A full Minecraft panel such as Crafty can
also sit behind Access, but it needs write access to server files and process
control. Add it only if browser-based console and file management are required;
that materially expands the administrative blast radius.

## Uptime Kuma additions

Add TCP monitors for Homestead `25565` and SkyFactory `25566`, HTTP monitors for
the public status API and both product pages, and a push or heartbeat monitor
for backups. Do not create a TCP monitor for UDP voice chat.

## Rollback

```bash
sudo systemctl disable --now alertmanager minecraft-exporter-homestead \
  minecraft-exporter-skyfactory parallel-works-metrics.timer
sudo systemctl enable --now minecraft_exporter
sudo cp /opt/prometheus/prometheus.yml.pre-observability /opt/prometheus/prometheus.yml
sudo systemctl restart prometheus grafana-server
```

The installer creates `/opt/prometheus/prometheus.yml.pre-observability` on its
first run and never overwrites that rollback copy.
