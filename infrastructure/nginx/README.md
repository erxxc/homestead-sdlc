# Nginx Configuration

Live Nginx configuration runs on the VPS — this directory is a structural placeholder.

## Production location
- Site configs: `/etc/nginx/sites-available/` on VPS, symlinked from `/etc/nginx/sites-enabled/`
- Main config: `/etc/nginx/nginx.conf`
- TLS certs: `/etc/letsencrypt/live/<hostname>/` (auto-renewed via certbot systemd timer)

## Active vhosts
| Vhost | Purpose | Upstream |
|---|---|---|
| `map.geigercapital.us` | BlueMap web UI | `127.0.0.1:8100` |
| `api.geigercapital.us` | Status API | `127.0.0.1:5000` (Flask) |

## Security controls applied
- TLS via Let's Encrypt — HTTPS enforced on both vhosts (pentest F-016 Remediated)
- HSTS — `Strict-Transport-Security: max-age=31536000; includeSubDomains` (F-011)
- CSP — set on both vhosts; BlueMap requires `unsafe-eval`/`unsafe-inline` for the renderer (F-002, F-017)
- Permissions-Policy — `geolocation=(), microphone=(), camera=()` (F-012)
- X-Content-Type-Options, X-Frame-Options, Referrer-Policy on API (F-013)
- `server_tokens off;` in `http` block — version disclosure suppressed (F-006)
- Rate limiting via `limit_req_zone` (F-010 confirms it actively blocks scanners)

## Control reference
- C-025 — TLS on web services
- C-026 — HTTP security headers
- C-027 — Rate limiting
- SOC2 CC6.6, ISO 27001 A.10.1.1 / A.14.2.5 / A.13.1.1, NIST CSF PR.DS-2 / PR.AC-5

## To export current configs into this dir
```
ssh vps "sudo cat /etc/nginx/sites-available/map.geigercapital.us" > infrastructure/nginx/map.conf
ssh vps "sudo cat /etc/nginx/sites-available/api.geigercapital.us" > infrastructure/nginx/api.conf
```

Strip any IP allow-lists, basic-auth credentials, or internal-only paths before committing.
