# Homestead SDLC PoC

Secure software development lifecycle proof-of-concept built around the Homestead SMP — a Fabric 1.20.1 / Homestead 1.3.6 Minecraft server hosted on a Hetzner CX43 VPS. 30 controls mapped to SOC 2 TSC, ISO 27001 Annex A, and NIST CSF.

Public site: [play.geigercapital.us](https://play.geigercapital.us) · Game: `mc.geigercapital.us` · Map: [map.geigercapital.us](https://map.geigercapital.us)

## Structure
- `infrastructure/` — systemd units, nginx, ufw, scheduled-restart script
- `monitoring/` — Prometheus + minecraft-exporter; Grafana + Uptime Kuma run on VPS (see READMEs)
- `security/` — mod integrity (inotify watcher + SHA-256 checksums), audit logger, backup verification, fail2ban
- `api/` — Flask status API serving sanitised public metrics
- `site/` — Cloudflare Pages landing site + getting-started guide + changelog
- `docs/` — threat model, control framework, SBOM, runbooks, pentest report, secrets policy, privacy notice
- `reports/` — Lynis, nmap, nikto, ZAP outputs; PoC summary PDF

## Implemented controls (highlights)
- Mod supply chain — SHA-256 checksums + systemd `ExecStartPre` verification + inotify auto-regen on jar changes
- Security audit log — Python daemon classifies player join/leave, OP grants, kicks/bans, RCON commands into structured JSON
- Scheduled restart — RCON-driven announcements + audit-logged `save-all flush` before systemd restart
- Backup verification — weekly integrity check script
- Log rotation — 30-day retention on audit and Nginx logs
- BlueMap POI markers — server spawn pinned on the live map
- CI/CD — CodeQL, Checkov, OWASP ZAP, Dependabot, gitleaks pre-commit, auto-deploy on push to main
- TLS + security headers — Let's Encrypt + HSTS/CSP/Permissions-Policy on all web vhosts

## Compliance target
SOC 2 TSC · ISO 27001 Annex A · CIS Ubuntu 24.04 · NIST CSF · GDPR (data minimisation)

See `docs/control-framework.md` for the full 30-control inventory with regulatory mappings.

## Status
PoC summary v1.1 published 2026-05-23 (see `reports/`). Threat model on a quarterly
review cadence — last reviewed 2026-08-13. Post-PoC work continues — see `CHANGELOG.md`
and `docs/threat-model/threat-model.md` for current control status.
