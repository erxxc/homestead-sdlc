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

- **RCON password visible in process list (F-001, Partial)** — `minecraft_exporter v0.6.1` passes `--mc.rcon-password=<value>` as a CLI argument, so the password is observable to any local user via `ps aux` or `/proc/<pid>/cmdline`. Repo-maintained RCON scripts now use direct socket clients to avoid CLI argument exposure. The secrets file itself is correctly restricted (`640 root:minecraft`); the remaining leak is in the exporter's process arguments. Full remediation requires replacing the exporter with a config-file-based alternative or a mod-based exporter. Tracked in `docs/pentest-report.md` F-001 and listed in v1.1 PoC recommendations.

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
