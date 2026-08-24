# OPS-005 — Uptime Kuma: pm2 → systemd, Node 22, failure alerting

## Purpose

Bring the availability monitor (C-019) under the same supervision and
alerting as every other service on the VPS. Uptime Kuma had been running
under a per-user `pm2` daemon, which reported the process "online" while it
crash-looped for 102 days (2026-05-14 → 2026-08-24); pm2 sits outside
systemd, so the OPS-004 `OnFailure=` path could never see it. Details in
`reports/2026-08-24-uptime-kuma-outage.md`.

After this runbook:

| Before | After |
|---|---|
| `pm2-eric.service` → pm2 → `node server/server.js` as `eric` | `uptime-kuma.service` → `node server/server.js` as system user `uptime-kuma` |
| Node 18.19.1 (Ubuntu package; below Kuma's `>= 20.4.0` floor) | Node 22.x (NodeSource, pinned, keyring-verified) |
| Unbounded `~/.pm2/logs/*.log` (reached 9.1 GB) | journald, size-capped |
| No failure signal | `OnFailure=minecraft-alert@%p.service`, start-limit 5 / 10 min |
| `/opt/uptime-kuma/data` root-owned (the crash cause), then `eric`-owned | `uptime-kuma:uptime-kuma`, 750/640 (the DB holds the Discord webhook) |

Repo artifacts: `infrastructure/systemd/uptime-kuma.service`,
`monitoring/uptime-kuma/migrate-to-systemd.sh`.

## Prerequisites

- Done 2026-08-24 in the operator's terminal: `chown` of the data dir away
  from root, `pm2 restart uptime-kuma`, `pm2 flush`. The script re-owns the
  data dir to the service user, so the interim owner does not matter.
- SSH access with sudo (port 2222). The script needs a password prompt, so
  run it in your own terminal — not through a non-interactive session.
- Outbound HTTPS to `deb.nodesource.com` for the apt repo and key.

## Steps

1. Stage the two files on the VPS (from the repo root, on your machine):

   ```bash
   ssh -p 2222 <admin-user>@mc.geigercapital.us 'mkdir -p /tmp/kuma-migrate'
   scp -P 2222 monitoring/uptime-kuma/migrate-to-systemd.sh \
       infrastructure/systemd/uptime-kuma.service \
       <admin-user>@mc.geigercapital.us:/tmp/kuma-migrate/
   ```

2. Run the migration (idempotent — re-run after any partial failure):

   ```bash
   ssh -t -p 2222 <admin-user>@mc.geigercapital.us \
       'sudo bash /tmp/kuma-migrate/migrate-to-systemd.sh'
   ```

   What it does, in order: installs Node 22 from NodeSource using a manually
   fetched keyring and a pinned `sources.list.d` entry (no `curl | bash`),
   confirms Kuma's sqlite binding loads under the new runtime (rebuilds it
   if not), creates the `uptime-kuma` system user and re-owns the data dir,
   deletes the pm2 process / daemon / `pm2-eric.service`, installs and
   starts the unit, waits for `:3001`, removes the global pm2 install, and
   prints the sudo-only evidence the 2026-08-24 review could not read.

3. Verify:

   ```bash
   systemctl is-active uptime-kuma            # active
   systemctl show -p OnFailure uptime-kuma    # minecraft-alert@uptime-kuma.service
   curl -s -o /dev/null -w '%{http_code}\n' localhost:3001/   # 302
   journalctl -u uptime-kuma -n 20 --no-pager
   node -v                                    # v22.x
   systemctl list-unit-files | grep pm2       # nothing
   ```

   Then open the Kuma UI (SSH tunnel: `ssh -p 2222 -L 3001:localhost:3001 …`
   → `http://localhost:3001`) and confirm the monitors are green.

4. Fix the pre-existing monitor misconfiguration: Monitor #4 "Voice Chat" is
   a TCP *port* check against Simple Voice Chat's **UDP** 24454, so it fails
   every minute. Kuma has no UDP probe — either delete it or replace it with
   a check that reflects reality (e.g. the Minecraft monitor already proves
   the host is up).

5. Optional: bind Kuma to loopback. `:3001` is blocked at UFW and the Hetzner
   firewall (C-005), so this is defence in depth, not a fix. Uncomment
   `Environment=UPTIME_KUMA_HOST=127.0.0.1` in the unit, redeploy it with
   `install` + `daemon-reload` + `restart`, and reach the UI via the tunnel
   above.

6. The pending kernel reboot (uptime > 100 days) doubles as the cold-boot
   validation: after it, repeat step 3.

## Failure notes

- `apt-get install nodejs` removes Ubuntu's `npm` and `libnode-dev` — the
  NodeSource package provides `npm` itself. The Ubuntu `node-*` library
  packages that `npm` pulled in stay installed but unused; the script prints
  the `apt-get autoremove` candidates without running it.
- If the unit is active but nothing listens on `:3001` within 30 s, the
  journal will show why (most likely `EADDRINUSE` from a leftover pm2
  process, or a data-dir permission error). Re-run the script — step 3
  waits for the port to free.
- Node from NodeSource is **not** covered by unattended-upgrades
  (`Allowed-Origins` is Ubuntu-only). Include `apt upgrade nodejs` in the
  monthly patch pass.

## Not done by the deploy workflow

`uptime-kuma.service` is installed by this runbook, not by
`.github/workflows/deploy.yml`, for the same reason as the exporter/Prometheus
units: the `github-actions` sudoers whitelist may be exact-path, and a new
`sudo install` target would fail the next deploy until it is covered. To bring
it under CI, run the OPS-002 step-0 preflight (`sudo -l -U github-actions`)
first, then add the unit to the deploy tarball and install loop.

## Rollback

```bash
sudo systemctl disable --now uptime-kuma.service
sudo chown -R eric:eric /opt/uptime-kuma/data
sudo npm install -g pm2
pm2 start /opt/uptime-kuma/server/server.js --name uptime-kuma && pm2 save
sudo env PATH="$PATH" pm2 startup systemd -u eric --hp /home/eric
```

Node 22 can stay; Kuma 2.x requires it anyway.
