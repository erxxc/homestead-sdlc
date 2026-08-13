# Incident & Remediation Report — 2026-08-13

Two related incidents surfaced and were remediated on 2026-08-13 during
planned security work. All times UTC.

## Incident 1 — Backup integrity failure (disk exhaustion)

### Impact

Between roughly 2026-08-11 and 2026-08-13 16:06, **no valid world backup
existed**. The three retained archives were all truncated by a full disk
(67 MB, 180 MB, 0 bytes — a healthy archive is ~15.3 GiB).

### Root cause chain

1. World growth pushed compressed backups to 15.3 GiB; the documented 7-day
   retention (C-021) implies ~107 GiB of archives, which the 150 GiB disk
   cannot hold alongside the 19 GiB live world and services.
2. The disk filled; nightly `tar | gzip` began truncating archives
   (`gzip: stdout: No space left on device`, service exit 2 on Aug 13 00:00).
3. Manual count-based pruning (keep newest 3) deleted the *older, valid*
   archives while retaining the *newest, corrupt* ones.
4. Backup verification had not run since 2026-05-24 (never scheduled; the
   last completed run was a FAIL), so the corruption was invisible.

### Resolution

- Fresh backup taken and verified 16:06:22 (`world-20260813-155710.tar.gz`,
  16,428,700,317 bytes, PASS).
- PR #43: backup lifecycle codified as systemd timers — backup 00:00,
  **verification 00:45 (new)**, size-capped prune 01:15 (50 GiB cap, min 2
  kept) replacing the cron age-based cleanup.
- Follow-up PR: `backup-world.sh` makes backups world-consistent and
  failure-proof — RCON `save-off` → `save-all flush` → tar to `.part` →
  atomic rename → `save-on`, with a free-disk preflight (≥20 GiB) so
  exhaustion fails loudly instead of writing truncated archives; prune gains
  an undersized-archive guard (<1 GiB = truncation garbage, deleted only
  when a healthy archive exists).
- Corrupt archives removed; C-021 evidence text updated.

### Lessons

- Retention must be sized against disk reality, not calendar convention.
- Verification is what converts "backups exist" into "backups work" — it is
  now scheduled daily and logged.
- Count-based pruning without integrity checks can preferentially destroy
  good data.

## Incident 2 — RCON consumer outage during OPS-001 execution

### Impact

~15:10–15:45: public status API reported the server offline while it was up;
player-count metric and scheduled-restart RCON path also broken. No game
impact.

### Root cause

OPS-001 added a second line (`MC_RCON_PASSWORD=`) to
`/etc/minecraft/secrets/rcon`. Three consumers parsed the secrets file
naively (whole file as the password) and failed RCON auth. The runbook
assumed line-based parsing without verifying consumer behavior.

### Resolution

- PR #42: line-based `RCON_PASSWORD=` parsing in `status-api.py`,
  `minecraft-online-players.sh`, `mc-restart.sh`; exporter unit gains
  `--web.listen-address=127.0.0.1:9225` (v0.24.0 ignores the legacy config
  listen address); OPS-001 secrets step rewritten to an idempotent
  two-line rewrite with expanded validation.
- Remediation script executed on the VPS: clean unit installed, exporter
  restarted, all consumers validated healthy.

### Outcome — F-001 closed

Exporter v0.24.0 now reads `MC_RCON_PASSWORD` from the restricted
EnvironmentFile. Evidence: no credential in `ps`/`/proc/<pid>/cmdline`;
exporter serving 217 metrics on 127.0.0.1:9225; UFW default-deny confirmed
for 25575. R-001 marked Implemented (threat model v1.3).

## Follow-ups

- [ ] Rotate the RCON password (historical process-list exposure) — next
      maintenance window, procedure in `docs/secrets-management.md`.
- [ ] Confirm first automated cycle (backup 00:00 / verify 00:45 / prune
      01:15) completes with PASS + OK log lines on 2026-08-14.
- [ ] Consider off-host backup copy (e.g. Hetzner Storage Box) so a single
      disk no longer holds both the world and all its backups.
