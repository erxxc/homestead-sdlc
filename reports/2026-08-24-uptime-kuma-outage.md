# Incident Report — 2026-08-24: Uptime Kuma silent outage (102 days)

Found during a routine review of the VPS automations on 2026-08-24. All times
UTC.

## Impact

From **2026-05-14 11:41** (a planned reboot) until **2026-08-24 16:10**, the
availability monitor (control C-019) was not running. No Minecraft, BlueMap,
or SSH heartbeat checks executed and no Discord alert could have fired for
any outage in that window. The gap spans the 2026-05-23 PoC summary, which
lists Uptime Kuma as a live control, and the 2026-08-13 backup incident.

Secondary impact: the supervisor's log files grew to **9.1 GB**
(`~/.pm2/logs/uptime-kuma-error.log` 6.7 GB, `-out.log` 2.5 GB, ≈90 MB/day)
on the single 150 GB disk that also holds the world and its backups. That is
a large share of the "base disk usage growth" that forced the backup
retention cap from 50 to 35 GiB on 2026-08-18.

## Detection

Not by monitoring. `systemctl --failed` was empty, every unit the OPS-004
alerting covers was healthy, and `pm2 list` showed the process as
**online** — with 382,359 restarts and an uptime of 0 s. The review noticed
that nothing was listening on `:3001`.

## Root cause chain

1. 2026-04-26 01:19 — Uptime Kuma was installed under `/opt/uptime-kuma` as
   root; the data directory and `kuma.db` were created root-owned (0644).
2. 2026-04-26 01:22 — a pm2 process was registered under the admin user's
   pm2 daemon (`pm2-eric.service`). It could not bind `:3001`
   (`EADDRINUSE`) because a separate, root-run instance was already serving
   the port and writing the root-owned database. The user-level process
   crash-looped from day one, masked by the working root instance.
3. 2026-05-11 00:20 — last write to `kuma.db`: the root-run instance
   stopped (not under any persistent supervisor).
4. 2026-05-14 11:41 — reboot. Only `pm2-eric.service` came back. Its Kuma
   now reached the database, failed on the first write
   (`Failed to prepare your database: update setting …` — read-only file for
   that user), exited, and pm2 relaunched it roughly every 3 s. This
   continued for 102 days.
5. Nothing escalated because pm2 reports a restarting process as "online"
   and it never enters a systemd `failed` state, so the OPS-004
   `OnFailure=` model (deployed 2026-08-20) could not observe it. Node
   18.19.1, below Kuma's `>= 20.4.0` floor, added a warning on every
   restart but was not the cause.

## Resolution

- 2026-08-24 16:10 — operator: `chown` of `/opt/uptime-kuma/data` away from
  root, `pm2 restart uptime-kuma`, `pm2 flush`. Kuma came up on `:3001`;
  9 GB reclaimed (disk 76 % → 70 % used).
- Runbook **OPS-005** (`docs/runbooks/OPS-005-uptime-kuma-systemd-migration.md`)
  with `monitoring/uptime-kuma/migrate-to-systemd.sh` and
  `infrastructure/systemd/uptime-kuma.service`: Node 22 from NodeSource via a
  manually fetched keyring and pinned source; a dedicated `uptime-kuma`
  system user owning the data dir (750/640 — the DB stores the Discord
  webhook); pm2 process, daemon, unit, and global install removed; Kuma
  under a hardened systemd unit with journald logging and
  `OnFailure=minecraft-alert@%p.service` behind a 5-in-10-min start limit.
- Documentation corrected: Kuma data path, service model, and the
  misconfigured "Voice Chat" monitor (TCP probe of a UDP port — fails every
  interval); `infrastructure/README.md` no longer claims `mc-restart` runs
  from a systemd timer; OPS-004 gains the "supervisor outside systemd"
  limitation.

## Lessons

- A supervisor that restarts forever is an alerting black hole. Everything
  on the box now runs as a native systemd unit, where the start-limit +
  `OnFailure=` pattern turns a crash loop into a page.
- "Process online" is not "service working". The review found this by
  checking the listening port, not the process list; a periodic external
  check of `:3001` (or Kuma's own status page) is the cheap complement.
- Ownership drift from ad-hoc root runs (`sudo node …`, `sudo pm2 …`) is a
  recurring failure mode — the 2026-08-13 backup outage had the same shape
  (`/opt/minecraft/backups` root-owned). Dedicated service users with
  explicit `chown` in the install path prevent it.
- Silent log growth is a disk-capacity risk on a single-disk host where the
  backup preflight refuses to run under 20 GiB free.

## Follow-ups

- [x] Run OPS-005 — done 2026-08-24 16:27: `uptime-kuma.service` active as
      `uptime-kuma`, `OnFailure=minecraft-alert@uptime-kuma.service`,
      Node v22.23.2, pm2 removed.
- [ ] Delete or replace the "Voice Chat" TCP monitor in the Kuma UI.
- [x] Reboot for the six pending kernel updates — done 2026-08-24 16:41
      (6.8.0-138, uptime reset from 102 days). Cold-boot validation passed:
      all services active with 0 restarts, `uptime-kuma.service` listening
      within the first boot minute, mod-integrity gate PASS, backup/verify/
      prune timers armed, no failed units.
- [ ] Add Kuma's `:3001` (or its status page) to an external check so a
      future outage is seen from outside the host.
- [ ] Note the C-019 evidence gap (2026-05-14 → 2026-08-24) in the next
      threat-model / control-framework review.
