# Uptime Kuma

Live Uptime Kuma runs on the VPS and is available to named operators through
Cloudflare Access at `https://status-admin.geigercapital.us`.

## Production location

- Install: `/opt/uptime-kuma` (Uptime Kuma 2.2.1, root-owned, read-only to the service)
- Data (SQLite): `/opt/uptime-kuma/data/kuma.db` — owned `uptime-kuma:uptime-kuma`, 750/640
  (the DB stores the Discord webhook)
- Service: `uptime-kuma.service` (repo: `infrastructure/systemd/uptime-kuma.service`),
  runs `node server/server.js` as the `uptime-kuma` system user on Node 22
  (NodeSource, pinned via `/etc/apt/preferences.d/nodesource`)
- Logs: `journalctl -u uptime-kuma` (journald is size-capped — no log files to rotate)
- UI origin: `http://127.0.0.1:3001`; the port remains blocked publicly and is
  published only through the authenticated outbound Cloudflare Tunnel
- Failure alerting: `OnFailure=minecraft-alert@%p.service` (OPS-004) with a 5-in-10-min
  start limit, so a crash loop pages instead of restarting forever

Until 2026-08-24 the process ran under a per-user `pm2` daemon. pm2 kept
reporting it "online" while it crash-looped for 102 days on a root-owned
database, filling 9 GB of logs — see
`reports/2026-08-24-uptime-kuma-outage.md` and runbook OPS-005 for the
migration. Do not reintroduce a supervisor outside systemd: anything that
never reaches systemd's `failed` state is invisible to the alerting.

## Active monitors

| Monitor | Target | Check |
|---|---|---|
| Homestead Game | `127.0.0.1:25565` | TCP port |
| SkyFactory Game | `127.0.0.1:25566` | TCP port |
| Homestead Status API | `http://127.0.0.1:5000/status` | HTTP GET |
| SkyFactory Status API | `http://127.0.0.1:5000/status/skyfactory4` | HTTP GET |
| Public API Edge | `https://api.geigercapital.us/health` | HTTP GET every 5 minutes |
| Homestead Page | `https://play.geigercapital.us/homestead.html` | HTTP GET |
| SkyFactory Page | `https://play.geigercapital.us/skyfactory.html` | HTTP GET |
| Cloudflare Tunnel | `http://127.0.0.1:2000/ready` | HTTP GET |
| Loki | `http://127.0.0.1:3100/ready` | HTTP GET |
| Alloy | `http://127.0.0.1:12345/-/ready` | HTTP GET |
| Homestead Verified Backup | local secret Push URL | Push heartbeat |
| SkyFactory Verified Backup | local secret Push URL | Push heartbeat |

Alerts route only to ntfy. The topic is stored outside the repository.

## Verified-backup heartbeat

Create Push monitors named `Homestead Verified Backup` and
`SkyFactory Verified Backup`, set each heartbeat interval to 26 hours with two
retries, and configure their generated URLs using
`infrastructure/configure-backup-heartbeat.sh homestead` and
`infrastructure/configure-backup-heartbeat.sh skyfactory4`. The configurator preserves the
secret push path but rewrites the origin to Kuma's loopback listener. A
heartbeat is sent only after `verify-backup` successfully extracts
`world/level.dat`; failed or missing verification becomes a missed heartbeat.

## Control reference

- C-019 — Availability monitoring
- SOC2 A1.1 / A1.2, ISO 27001 A.17.1.1, NIST CSF DE.CM-1

## To export monitor config into this dir

In the Uptime Kuma UI: Settings → Backup → Export → save to `monitoring/uptime-kuma/monitors.json`.

The ntfy topic and Push URLs are secrets and must not be committed. Strip all
notification configuration and Push tokens from exports before adding one to
the repository.
