# Uptime Kuma

Live Uptime Kuma instance runs on the VPS — this directory is a structural placeholder for exported monitor config.

## Production location
- Service: Uptime Kuma on the VPS (restricted access)
- SQLite database: `/var/lib/uptime-kuma/kuma.db` on VPS

## Active monitors
| Monitor | Target | Check |
|---|---|---|
| Minecraft | `mc.geigercapital.us:25565` | TCP port |
| BlueMap | `map.geigercapital.us` | HTTP GET (HEAD returns 400 — see pentest F-005) |
| SSH | VPS:2222 | TCP port |

Alerts route to Discord via webhook.

## Control reference
- C-019 — Availability monitoring
- SOC2 A1.1 / A1.2, ISO 27001 A.17.1.1, NIST CSF DE.CM-1

## To export monitor config into this dir
In the Uptime Kuma UI: Settings → Backup → Export → save to `monitoring/uptime-kuma/monitors.json`.

The Discord webhook URL is a secret and must not be committed — strip it from any exported notification config before adding to the repo.
