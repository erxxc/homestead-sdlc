# Secrets Management Policy

## Scope
All credentials, API keys, and sensitive configuration values used in the Homestead SDLC PoC.

## Inventory

| Secret | Location | Access | Rotation |
|---|---|---|---|
| RCON password | /etc/minecraft/secrets/rcon | root only (600) | Monthly |
| SSH private key | ~/.ssh/id_ed25519 | eric only | Annual |
| GitHub deploy key | ~/.ssh/github_deploy_key | root only | Annual |
| GitHub Secrets | GitHub repo settings | Admin only | On compromise |

## Rules
- No secrets committed to version control under any circumstances
- gitleaks pre-commit hook enforced on all commits
- Secrets files chmod 600, owned by root
- Shell history cleared after any secret is handled manually
- Rotation schedule documented above and reviewed monthly

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
