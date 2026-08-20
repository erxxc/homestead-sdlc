# Infrastructure

Configuration files and operational scripts for the Homestead SDLC PoC.

## Contents

### Subdirectories
- `systemd/` — service unit files (Minecraft audit logger, mod-watcher, exporters)
- `nginx/` — reverse-proxy configuration (see `nginx/README.md` for the production VPS mapping)
- `ufw/` — firewall rules export (see `ufw/README.md`)

### Standalone files
- `mc-restart.sh` — RCON-driven scheduled-restart script with player announcements, audit logging, and `save-all flush`. Invoked via systemd timer on the VPS.
- `systemd/minecraft-alert@.service` + `systemd/onfailure-alert.conf` — failure alerting: any unit declaring `OnFailure=minecraft-alert@%p.service` (natively or via the drop-in) pushes an ntfy notification when it enters failed state. See runbook OPS-004.
- `minecraft-logrotate.conf` — log rotation policy for the audit log and Nginx logs (30-day retention). Sole owner of the Nginx logs: the stock `/etc/logrotate.d/nginx` is deleted on the VPS (a duplicate claim makes the nightly logrotate run exit 1), and the deploy workflow fails validation if it reappears.
- `bluemap-world.conf` — BlueMap world-rendering config, including POI marker definitions (server spawn pin)
