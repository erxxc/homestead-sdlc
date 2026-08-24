# Uptime Kuma

Live Uptime Kuma instance runs on the VPS — this directory holds the
systemd migration script; exported monitor config can be added alongside.

## Production location

- Install: `/opt/uptime-kuma` (Uptime Kuma 2.2.1, root-owned, read-only to the service)
- Data (SQLite): `/opt/uptime-kuma/data/kuma.db` — owned `uptime-kuma:uptime-kuma`, 750/640
  (the DB stores the Discord webhook)
- Service: `uptime-kuma.service` (repo: `infrastructure/systemd/uptime-kuma.service`),
  runs `node server/server.js` as the `uptime-kuma` system user on Node 22
  (NodeSource, pinned via `/etc/apt/preferences.d/nodesource`)
- Logs: `journalctl -u uptime-kuma` (journald is size-capped — no log files to rotate)
- UI: `http://localhost:3001` on the VPS; `:3001` is blocked at UFW + Hetzner (C-005),
  so reach it through `ssh -p 2222 -L 3001:localhost:3001 <admin-user>@mc.geigercapital.us`
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
| Minecraft | `mc.geigercapital.us:25565` | TCP port |
| BlueMap | `map.geigercapital.us` | HTTP GET (HEAD returns 400 — see pentest F-005) |
| SSH | VPS:2222 | TCP port |
| Voice Chat | VPS:24454 | TCP port — **misconfigured**: Simple Voice Chat is UDP, so this fails every interval; Kuma has no UDP probe. Delete or replace (OPS-005 step 4). |

Alerts route to Discord via webhook.

## Control reference

- C-019 — Availability monitoring
- SOC2 A1.1 / A1.2, ISO 27001 A.17.1.1, NIST CSF DE.CM-1

## To export monitor config into this dir

In the Uptime Kuma UI: Settings → Backup → Export → save to `monitoring/uptime-kuma/monitors.json`.

The Discord webhook URL is a secret and must not be committed — strip it from any exported notification config before adding to the repo.
