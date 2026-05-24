# Post-PR Audit Follow-Up - 2026-05-24

This note records the additional findings, production fixes, and CI evidence
changes made after the public PR readiness review.

## Additional Findings

| Area | Finding | Resolution |
|---|---|---|
| VPS deploy automation | Runtime files were present in the repository but not deployed to the VPS by GitHub Actions. | Deploy workflow now packages runtime files, copies them to the VPS, installs them into production paths, restarts affected services, and records the deployed commit. |
| Deploy service naming | The live status API service is `minecraft-status-api.service`, not the generic status API name originally assumed. | Deploy workflow now uses `STATUS_API_SERVICE=minecraft-status-api`. |
| Backup verification | Backup verification could fail silently and originally assumed a single archive path shape for `level.dat`. | `security/verify-backup.sh` now logs to stdout and `/var/log/minecraft-backup-verify.log`, checks both `world/level.dat` and `./world/level.dat`, and exits non-zero on failure. |
| Deploy validation blast radius | Running full backup verification during every deploy made unrelated backup state capable of failing code deploys. | Deploy validation now syntax-checks the script and confirms it is executable; scheduled/manual backup verification remains the integrity evidence path. |
| Log rotation | Minecraft audit and integrity logrotate stanzas needed an explicit user directive for reliable non-interactive validation. | `infrastructure/minecraft-logrotate.conf` now includes `su root root` for the Minecraft audit and integrity logs. |
| Status API validation | Public API status briefly showed offline even while the service was running, and player count checks depended on local RCON behavior. | Deploy validation now curls `http://127.0.0.1:5000/status`, validates JSON shape and map URL, and verifies the node-exporter textfile metric is populated. |
| RCON secret naming | The Minecraft property is lowercase `rcon.password`; GitHub/VPS secret naming uses uppercase `RCON_PASSWORD`. | Accepted as naming-context difference. The important connection point is that both values must contain the same secret. |
| ZAP issue creation | ZAP attempted to create GitHub issues from scan findings. | `.github/workflows/zap.yml` now sets `allow_issue_writing: false`; scan output remains available as Actions artifacts. |
| ZAP manual evidence | ZAP was scheduled/push-triggered but not manually launchable for controlled evidence runs. | Added `workflow_dispatch` to the ZAP workflow. |
| CodeQL and Checkov manual evidence | CodeQL and Checkov were not manually launchable for ad hoc evidence refreshes. | Added `workflow_dispatch` to both workflows. |
| ZAP scanner identity | Adding a custom ZAP User-Agent caused the action to fail during startup. | Reverted the custom User-Agent. Scanner identity is documented through workflow name, run ID, and artifact metadata instead. |
| BlueMap robots path | `/robots.txt` was not explicitly served by the origin and contributed scan noise. | Live Nginx config now serves `200 text/plain` robots.txt for `map.geigercapital.us`. |
| Origin security headers | Some security headers were absent on non-2xx paths. | Live Nginx headers were updated with `always` so error and auxiliary responses receive the same security header set. |
| Cloudflare HSTS | Cloudflare dashboard HSTS could not be enabled in the current configuration. | HSTS is enforced at the origin Nginx layer for the public VPS vhosts. |

## Changes Deployed or Pushed

- Added GitHub Actions VPS deployment of status API, BlueMap config, restart
  script, audit logger, mod watcher, backup verifier, logrotate config, and
  related systemd service files.
- Added deploy concurrency with `cancel-in-progress` to avoid overlapping VPS
  deploys.
- Tightened deploy validation around service health, local API JSON, player
  metrics, script syntax, and logrotate dry-run.
- Created a dedicated `github-actions` VPS user for CI deploys with limited
  sudo command scope.
- Updated VPS sudoers for the deploy user as the workflow needs became clear.
- Confirmed the live status API process is managed by
  `minecraft-status-api.service`.
- Updated backup verification behavior to produce visible PASS/FAIL evidence.
- Updated live Nginx for BlueMap robots.txt and `always` security headers.
- Added manual launch triggers for ZAP, CodeQL, and Checkov evidence scans.
- Disabled ZAP GitHub issue writing while preserving scan artifacts.

## Latest Evidence Snapshot

- ZAP run `26372121670` completed successfully.
- ZAP result summary: `FAIL-NEW: 0`, `WARN-NEW: 5`, `PASS: 137`.
- Remaining ZAP warnings are accepted or low-risk tuning candidates:
  HSTS header noise, CSP fallback directives, timestamp disclosure, proxy
  disclosure, and Cross-Origin-Resource-Policy.
- Public checks after Nginx tuning confirmed `https://map.geigercapital.us/`
  and `https://map.geigercapital.us/robots.txt` return `200` with the expected
  security headers.

## Closed Follow-Up Items

- Runtime deployment to the VPS is now handled by GitHub Actions instead of
  manual copy steps.
- A dedicated `github-actions` VPS user exists for workflow deployments.
- Deploy sudoers syntax was corrected and validated with `visudo`.
- The live status API service name was confirmed as
  `minecraft-status-api.service`.
- Deploy validation now checks local status API JSON and player metric output.
- Backup verification no longer fails silently and no longer depends on listing
  the full archive.
- Backup verification was removed from the deploy path to avoid coupling code
  deploys to unrelated backup state.
- ZAP issue creation was disabled.
- ZAP, CodeQL, and Checkov now support manual evidence launches.
- The failed custom ZAP User-Agent experiment was reverted.
- BlueMap origin Nginx now serves `/robots.txt` explicitly.
- BlueMap origin Nginx now applies security headers with `always`.

## Recommended Security Priority Backlog

1. Replace or rework `minecraft_exporter` RCON handling.
   This is the highest-priority technical debt because the exporter exposes the
   RCON password through process arguments. Preferred remediation is a small
   local metrics exporter or replacement exporter that reads a restricted config
   or secret file without passing credentials on the command line.
2. Add systemd hardening to custom services.
   Start with lower-risk services such as `minecraft-status-api.service`,
   `minecraft-audit.service`, and `minecraft-mod-watcher.service`; test
   `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem`, `ProtectHome`, and narrow
   `ReadWritePaths` one service at a time.
3. Add a repeatable evidence collection workflow.
   A manual workflow should gather the deployed commit, status API health,
   latest backup verification PASS line, service states, Nginx header checks,
   and scan run references.
4. Strengthen backup verification operations.
   Add operator procedures for failed verification, quarantined backups, and
   restore-validation evidence.
5. Tune or formally accept remaining ZAP warnings.
   Remaining candidates include HSTS noise, BlueMap CSP fallback directives,
   timestamp disclosure, proxy disclosure, and Cross-Origin-Resource-Policy.
6. Reduce origin exposure where feasible.
   Consider Cloudflare Tunnel or equivalent for web surfaces if the operational
   tradeoff is acceptable.

## Remaining Follow-Up

- Re-run ZAP manually after the Cloudflare and Nginx changes when final evidence
  is needed.
- Launch CodeQL and Checkov manually from GitHub Actions for matching evidence
  timestamps.
- Keep `minecraft_exporter` RCON CLI argument exposure as the primary accepted
  PoC risk until the exporter can be replaced or reworked.
- Consider Cloudflare Tunnel if the remaining direct-origin exposure should be
  eliminated.
