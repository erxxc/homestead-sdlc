# Mod Integrity Verification

This directory is a structural placeholder. The actual integrity-control assets are split between the repo's `security/` parent directory (scripts) and the VPS (live baseline).

## Repo scripts
- `../mod-watcher.sh` — inotify watcher; logs jar add/delete/modify events for manual review
- `../regenerate-checksums.sh` — generates SHA-256 baseline over all jars in `/opt/minecraft/homestead/mods/`
- `../../infrastructure/systemd/minecraft-mod-watcher.service` — runs the watcher under systemd
- `../verify-backup.sh` — periodic backup integrity check

## VPS-side artifacts
- Baseline file: `/opt/minecraft/homestead/mod_checksums.sha256`
- Integrity log: `/var/log/minecraft-integrity.log`
- Verification gate: `ExecStartPre` on `minecraft.service` — server refuses to start if any checksum fails

## Current state
- 427 server-side mod jars under integrity tracking (see `docs/sbom.md`)
- Baseline regeneration is manual after approved mod additions/updates
- Modpack: Homestead 1.3.6

## Control reference
- C-011 — Mod integrity verification (SHA-256 + ExecStartPre)
- C-012 — Software bill of materials (`docs/sbom.md`)
- SOC2 CC7.1, ISO 27001 A.12.5.1, NIST CSF PR.DS-6
- Threat model: Mod Supply Chain component (5 rows now Implemented)
- Runbook: `docs/runbooks/IR-003-malicious-mod.md`
