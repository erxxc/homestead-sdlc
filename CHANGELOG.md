# Changelog

## [Unreleased]
### Security
- Closed pentest finding F-001 / risk R-001: minecraft-exporter v0.24.0 reads
  the RCON credential from the restricted EnvironmentFile; no credential in
  the process list (threat model v1.3).
- Post-incident report for the 2026-08-13 backup integrity failure and RCON
  consumer outage (`reports/2026-08-13-backup-incident-and-rcon-remediation.md`).

### Added
- Public site: new Ops & Security page documenting the pipeline, backup
  lifecycle, supply-chain gate, pentest/threat-model process (including the
  F-001 arc and the 2026-08-13 incident), and measured performance —
  linked from every page nav, the command palette, and a new SDLC
  changelog entry.
- Installed the OPS-003 performance stack 2026-08-13 (spark, FerriteCore,
  ModernFix, Krypton, Lithium) via `security/install-mods.sh` — every jar
  SHA-512-verified, compatibility preflighted against the live loader, and
  admitted through the R-003 checksum gate (428 mods baselined).
- OPS-003 runbook: spark-first performance mod rollout (FerriteCore,
  ModernFix, Krypton, Lithium pinned with SHA-512 from Modrinth) through the
  existing mod supply-chain gate, plus world-border/Chunky pre-generation
  phase.
- Backup service now runs at Nice=19 with idle I/O scheduling so the
  midnight archive never competes with the game tick.
- World-consistent backup script: RCON save-off → save-all flush → tar to
  `.part` → atomic rename → save-on, with a ≥20 GiB free-disk preflight;
  prune now removes undersized truncation stubs when a healthy archive exists.
- Repo-managed backup lifecycle: codified daily backup units, new scheduled
  verification (00:45 UTC), and size-capped pruning (50 GiB cap, min 2 kept)
  replacing the on-VPS cron age-based cleanup; deployed via GitHub Actions
  with logrotate coverage for verify/prune logs. See runbook OPS-002.

### Fixed
- Nightly logrotate run no longer exits 1 (failing silently since 2026-04-26):
  `minecraft-logrotate.conf` and the stock nginx package config both claimed
  the nginx logs, so logrotate flagged a duplicate and marked the unit failed
  every night — rotation itself kept working via our stanza. Resolution keeps
  the repo-managed 30-day stanza as sole owner, deletes the stock
  `/etc/logrotate.d/nginx`, and adds a deploy validation that fails if the
  stock file reappears.
- Backup retention cap rightsized 50 → 35 GiB (2026-08-18): base disk usage
  growth left less than the backup preflight's 20 GiB floor free with three
  archives retained, so the 00:00 backup correctly refused to run. Two
  archives steady-state restores writing headroom; sizing rule documented
  in OPS-002.
- RCON secrets-file parsing in status API, player-count metric script, and
  restart script now reads the `RCON_PASSWORD=` line instead of the whole
  file, tolerating the multi-line EnvironmentFile format OPS-001 introduces.
- Exporter unit passes `--web.listen-address=127.0.0.1:9225` — minecraft-exporter
  v0.24.0 ignores the legacy config-file listen address.
- OPS-001 secrets step is now an idempotent file rewrite with expanded
  post-change validation (exporter port, status API online flag, UFW check).

### Changed
- August 2026 dependency refresh via Dependabot: actions/checkout v7,
  markdownlint-cli2-action v24, flask-cors 6.0.5 merged; checkov-action,
  setup-python v7, and codeql-action 4.37.3 bumps in review.
- Quarterly threat-model review completed 2026-08-13 (v1.2) — no new threats,
  next review 2026-11-13.

### Fixed
- Deploy validation now retries the local status API check until the service
  accepts connections, fixing a restart race that failed otherwise healthy
  deploys.

## SDLC hardening — 2026-05-24
### Added
- Manual GitHub Actions launch triggers for ZAP, CodeQL, and Checkov evidence scans.
- Post-PR audit follow-up report covering VPS deploy, backup verification, Nginx tuning, and scan evidence updates.

### Changed
- Expanded GitHub Actions deploy to install runtime files on the VPS, restart affected services, and validate local API and metric health.
- Updated backup verification logging and archive path checks for clearer PASS/FAIL evidence.
- Tightened Minecraft logrotate validation with explicit `su root root` directives.

### Security
- Disabled ZAP GitHub issue writing while preserving scan artifacts.
- Tuned live BlueMap Nginx handling for `robots.txt` and security headers on non-2xx responses.

## [1.3.6] — 2026-05-15
- Minor modpack update — no notable changes

## [1.3.5] — 2026-05-07
- Minor modpack update — no notable changes

## [1.3.4] — 2026-05-02
### Changed
- Upgraded Homestead modpack 1.3.1 → 1.3.4
- JVM heap increased to Xmx10G for expanded mod set
- RAM baseline: 4.3GB (down from 8.8GB after client mod cleanup)
### Fixed
- Obsidian smithing template (Obsidian Equipment Reworked 0.4)
- Abacus out-of-memory error
### Added
- Create: Slice & Dice
### Removed
- JER (was causing server crashes)
- Client-only mods from server deployment

## [1.3.1] — 2026-04-10
### Added
- Initial Homestead server launch on Fabric 1.20.1

## SDLC PoC — 2026-04-26
### Added
- Initial repository structure
- CI/CD pipeline scaffolding
