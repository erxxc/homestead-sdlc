# Changelog

## [Unreleased]
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
