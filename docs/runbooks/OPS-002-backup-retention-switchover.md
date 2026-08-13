# OPS-002 — Backup Retention Switchover (size-capped, verified)

## Purpose

Replace the age-based `/etc/cron.daily/minecraft-backup-cleanup` (7-day
retention — ~107 GiB at current 15.3 GiB backup size, which the 150 GiB disk
cannot hold) with repo-managed systemd timers:

| Timer | Time (UTC) | Does |
|---|---|---|
| minecraft-backup.timer | 00:00 | tar world to /opt/minecraft/backups (existing, now codified) |
| minecraft-backup-verify.timer | 00:45 | verify newest archive, PASS/FAIL to log (closes the gap that left verification dark 2026-05-24 → 2026-08-13) |
| minecraft-backup-prune.timer | 01:15 | delete oldest until total ≤ 50 GiB, always keeping the 2 newest |

Control C-021. Cap and floor are set in `minecraft-backup-prune.service`
(`CAP_GIB=50`, `MIN_KEEP=2`) — change via PR, not on the box.

## Step 0 — sudoers preflight (BEFORE merging the PR)

The deploy workflow gains new `sudo install` targets. If
`/etc/sudoers.d/github-actions-homestead` whitelists exact commands, the next
deploy fails until it covers them. Check:

```bash
sudo -l -U github-actions
```

If `install` entries are exact-path, mirror the existing pattern for:

- `/usr/local/bin/prune-backups`
- `/etc/systemd/system/minecraft-backup.service` and `.timer`
- `/etc/systemd/system/minecraft-backup-verify.service` and `.timer`
- `/etc/systemd/system/minecraft-backup-prune.service` and `.timer`

Edit only with `visudo -f /etc/sudoers.d/github-actions-homestead` and
validate with `visudo -c`.

## Steps

1. Merge the retention PR; wait for the Deploy to VPS run to pass. This
   installs the script and all six units and runs `daemon-reload`.
2. Enable the timers (idempotent if already enabled):

   ```bash
   sudo systemctl enable --now minecraft-backup.timer minecraft-backup-verify.timer minecraft-backup-prune.timer
   systemctl list-timers | grep minecraft
   ```

3. Remove the superseded cron job:

   ```bash
   sudo rm /etc/cron.daily/minecraft-backup-cleanup
   ```

4. Initial prune run and evidence:

   ```bash
   sudo systemctl start minecraft-backup-prune.service
   sudo tail -5 /var/log/minecraft-backup-prune.log
   sudo ls -laht /opt/minecraft/backups/ | head -6
   df -h /
   ```

5. Next-morning check (evidence for C-021):

   ```bash
   systemctl list-timers | grep minecraft
   sudo tail -2 /var/log/minecraft-backup-verify.log   # expect PASS
   sudo tail -2 /var/log/minecraft-backup-prune.log    # expect OK kept=...
   ```

## Failure notes

- A FAIL in the verify log means the newest backup is bad — investigate
  before the next prune cycle; `MIN_KEEP=2` guarantees the previous archive
  survives one bad night.
- If the backup service fails again with tar exit 2 in milliseconds, check
  `/opt/minecraft/backups` exists and is owned `minecraft:minecraft`
  (root-cause of the 2026-08-13 outage).

## Rollback

```bash
sudo systemctl disable --now minecraft-backup-verify.timer minecraft-backup-prune.timer
printf '#!/bin/bash\nfind /opt/minecraft/backups -name "*.tar.gz" -mtime +7 -delete\n' | sudo tee /etc/cron.daily/minecraft-backup-cleanup
sudo chmod 755 /etc/cron.daily/minecraft-backup-cleanup
```
