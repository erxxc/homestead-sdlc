# OPS-004 — Failure Alerting (OnFailure → ntfy push)

## Purpose

Close the silent-failure gap: the 2026-08-18 backup preflight refusal went
unnoticed for 13+ hours, and the nightly logrotate duplicate error went
unnoticed for ~4 months. Any monitored unit that enters systemd's `failed`
state now pushes a high-priority notification to the admin's phone within
seconds, carrying the unit's result, exit status, and last journal lines.

## Architecture

```
<unit>.service  --OnFailure=minecraft-alert@%p.service-->  minecraft-alert@<unit>.service
                                                              └── /usr/local/bin/notify-failure <unit>
                                                                    ├── reads ALERT_URL from /etc/minecraft/secrets/alerts
                                                                    ├── gathers systemctl show + last 10 journal lines
                                                                    └── POSTs to https://ntfy.sh/<topic>  (HTTPS, retry 3x)
```

- `minecraft-alert@.service` is a templated oneshot (repo:
  `infrastructure/systemd/minecraft-alert@.service`). It deliberately has no
  `OnFailure=` of its own, so a broken alert path can never loop.
- `%p` passes the failed unit's name without the `.service` suffix; the
  notifier re-appends it for display and journal lookup.
- The ntfy topic is the credential. It lives only in
  `/etc/minecraft/secrets/alerts` (600 root:root, one `ALERT_URL=` line,
  line-based parsing per secrets-management.md) — never in the repo, argv,
  or terminal output.

## Covered units

Native `OnFailure=` lines (repo-owned units, deployed from
`infrastructure/systemd/`):

- `minecraft-backup.service`, `minecraft-backup-verify.service`,
  `minecraft-backup-prune.service`
- `minecraft-audit.service`, `minecraft-mod-watcher.service` — these two run
  with `Restart=always`, and under systemd's default 10-second start-limit
  window a crash-loop restarts forever without ever reaching `failed`, so
  `OnFailure=` would never fire. Both now set `StartLimitIntervalSec=10min` /
  `StartLimitBurst=5`: five failures inside ten minutes stops the loop,
  marks the unit failed, and pages. A one-off crash still just restarts.

Drop-in coverage (units the repo does not own — deploy installs
`infrastructure/systemd/onfailure-alert.conf` as
`/etc/systemd/system/<unit>.service.d/onfailure-alert.conf`):

- `logrotate.service` (the 4-month silent failure this control answers)
- `minecraft.service`, `minecraft-status-api.service`,
  `minecraft_exporter.service` — drop-ins add alerting only; their restart
  behavior is untouched, so the alert fires whenever systemd itself gives up.

## One-time channel setup

Run `security/setup-alerts.sh` (copy it to the VPS, e.g. `/tmp/setup-alerts.sh`,
then `sudo bash /tmp/setup-alerts.sh`) **in your own terminal, not through a
Claude session** — the script prints the topic once, and the topic is the
credential. It generates a random `homestead-<20 chars>` topic, writes
`/etc/minecraft/secrets/alerts`, and sends a test push. Subscribe to the
topic in the ntfy app (iOS/Android) or keep `https://ntfy.sh/<topic>` open
in a browser. The script refuses to overwrite an existing config.

## Smoke test (end to end)

```bash
sudo systemd-run --unit=alert-smoke \
  --property=OnFailure=minecraft-alert@alert-smoke.service /bin/false
# expect a push within ~10s, then clean up the transient failed unit:
sudo systemctl reset-failed alert-smoke.service
```

## Rotating the topic

Treat like any credential rotation: delete
`/etc/minecraft/secrets/alerts`, re-run `setup-alerts.sh`, subscribe to the
new topic, unsubscribe from the old. Rotate if the topic ever appears in a
terminal transcript, screenshot, or shell history.

## Adding coverage to a new unit

- Repo-owned unit: add `OnFailure=minecraft-alert@%p.service` to `[Unit]`.
  If it has `Restart=`, check the start-limit math actually allows `failed`
  to be reached.
- Foreign unit: add its name to the drop-in loop in
  `.github/workflows/deploy.yml`.

## Limitations

- ntfy.sh is a public relay: anyone who learns the topic can read alerts
  (hostname, unit names, journal tails) or send fakes. The random topic +
  root-only secrets file is accepted for this PoC; self-hosted ntfy or an
  authenticated channel is the upgrade path.
- `OnFailure=` fires on entry to `failed` state only. It does not catch a
  timer that never fires (e.g. wall-clock issues) — the inverse-heartbeat
  model (Uptime Kuma push monitor on backup success) remains a possible
  complement, tracked in the backlog.
- Alert delivery depends on outbound HTTPS from the VPS; `curl` retries 3×
  with backoff, and a failed send lands in `minecraft-alert@*.service`
  journal (visible in `systemctl --failed` on the next checkup).
