# Secrets Management Policy

## Scope

All credentials, API keys, and sensitive configuration values used in the Homestead SDLC PoC.

## Inventory

| Secret | Location | Access | Rotation |
|---|---|---|---|
| RCON password | /etc/minecraft/secrets/rcon | 640, root:minecraft | Monthly |
| SSH private key | ~/.ssh/id_ed25519 | eric only | Annual |
| GitHub deploy key | ~/.ssh/github_deploy_key | root only | Annual |
| GitHub Secrets | GitHub repo settings | Admin only | On compromise |

## Rules

- No secrets committed to version control under any circumstances
- gitleaks pre-commit hook enforced on all commits
- Secret files chmod tightest viable (`600` where only root reads; `640 root:<group>` where a service account needs read access)
- Shell history cleared after any secret is handled manually
- Rotation schedule documented above and reviewed monthly

## Known Limitations

- **RCON password process-list exposure (F-001) — RESOLVED 2026-08-13.** Exporter upgraded to v0.24.0 per `docs/runbooks/OPS-001-exporter-credential-upgrade.md`; the credential is now supplied via `MC_RCON_PASSWORD` in the restricted EnvironmentFile (which holds exactly two lines: `RCON_PASSWORD=` and `MC_RCON_PASSWORD=`, same value). Verified: no credential in `ps`/`/proc/<pid>/cmdline`.
- **Password rotation pending** — the previous RCON password was exposed via the process list for months before F-001 closed; rotate per the procedure below at the next maintenance window.

## Rotation Procedure — RCON

1. Generate new password: openssl rand -base64 24
2. Update /etc/minecraft/secrets/rcon
3. Update rcon.password in server.properties
4. Restart minecraft service
5. Verify RCON connectivity
6. Clear shell history

## Incident Response

If a secret is suspected compromised:

1. Rotate immediately following procedure above
2. Review logs for unauthorised access
3. Document in incident log
4. Update this document with date and nature of rotation
