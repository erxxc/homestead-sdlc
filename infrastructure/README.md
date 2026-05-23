# Infrastructure

Configuration files and operational scripts for the Homestead SDLC PoC.

## Contents

### Subdirectories
- `systemd/` — service unit files (Minecraft audit logger, mod-watcher, exporters)
- `nginx/` — reverse-proxy configuration (see `nginx/README.md` for the production VPS mapping)
- `ufw/` — firewall rules export (see `ufw/README.md`)

### Standalone files
- `mc-restart.sh` — RCON-driven scheduled-restart script with player announcements, audit logging, and `save-all flush`. Invoked via systemd timer on the VPS.
- `minecraft-logrotate.conf` — log rotation policy for the audit log and Nginx logs (30-day retention)
- `bluemap-world.conf` — BlueMap world-rendering config, including POI marker definitions (server spawn pin)
