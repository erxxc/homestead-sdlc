# Homestead SDLC PoC

Secure software development lifecycle proof-of-concept built on the Homestead SMP Minecraft server infrastructure.

## Structure
- `infrastructure/` — systemd, nginx, firewall configs
- `monitoring/` — Prometheus, Grafana, Uptime Kuma
- `security/` — mod integrity, audit logging, fail2ban
- `api/` — server status API
- `site/` — Cloudflare Pages public site
- `docs/` — threat model, runbooks, compliance docs
- `reports/` — Lynis and pentest reports

## Compliance Target
SOC 2 TSC · ISO 27001 Annex A · CIS Ubuntu 24.04
