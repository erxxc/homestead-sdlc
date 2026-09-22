# Infrastructure

Configuration files and operational scripts for Parallel Works. Homestead and
SkyFactory are isolated world products on the shared operating layer.

## Contents

### Subdirectories
- `systemd/` — service unit files (Minecraft audit logger, mod-watcher, exporters, backup lifecycle timers, failure-alert template, Uptime Kuma)
- `nginx/` — reverse-proxy configuration (see `nginx/README.md` for the production VPS mapping)
- `ufw/` — firewall rules export (see `ufw/README.md`)

### Standalone files
- `mc-restart.sh` — RCON-driven scheduled-restart script with player announcements, audit logging, and `save-all flush`. Invoked from root's crontab on the VPS (Sundays 03:00 UTC — a 10-minute countdown, then `systemctl restart minecraft`); it is not a systemd timer, so it does not appear in `systemctl list-timers`.
- `systemd/uptime-kuma.service` — Uptime Kuma as a hardened native unit (dedicated system user, journald, `OnFailure=` alerting). Installed by runbook OPS-005 / `monitoring/uptime-kuma/migrate-to-systemd.sh`, not by the deploy workflow.
- `install-cloudflared-admin.sh` — installs the outbound-only administrative
  tunnel from Cloudflare's signed apt repository and runs it as an unprivileged
  service with a file-backed token.
- `systemd/minecraft-alert@.service` + `systemd/onfailure-alert.conf` — failure alerting: any unit declaring `OnFailure=minecraft-alert@%p.service` (natively or via the drop-in) pushes an ntfy notification when it enters failed state. See runbook OPS-004.
- `minecraft-logrotate.conf` — log rotation policy for the audit log and Nginx logs (30-day retention). Sole owner of the Nginx logs: the stock `/etc/logrotate.d/nginx` is deleted on the VPS (a duplicate claim makes the nightly logrotate run exit 1), and the deploy workflow fails validation if it reappears.
- `bluemap-world.conf` — BlueMap world-rendering config, including POI marker definitions (server spawn pin)

## Planned migration

The Minecraft 1.21.1 NeoForge pack uses a fresh world in a separate,
loopback-only staging instance. See
`docs/runbooks/OPS-007-neoforge-1.21.1-migration.md` and the feature-preservation
matrix under `docs/migrations/`. The complete production 1.20.1 runtime remains
untouched as the rollback instance.

For temporary packs, OPS-008 defines isolated runtimes and a future atomic
switch path. SkyFactory 4 currently runs beside Homestead on TCP 25566 with its
own Forge 1.12.2 runtime, Java 8 binary, world, and logs. Homestead remains on
TCP 25565 and neither service opens the other's world.
