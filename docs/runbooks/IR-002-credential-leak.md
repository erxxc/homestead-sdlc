# IR-002 — RCON Credential Exposure

## Trigger
- RCON password found in public location (GitHub, pastebin, etc.)
- Unauthorised RCON commands observed in audit log
- gitleaks pre-commit hook fires on password pattern

## Severity
Critical — RCON provides full server control including stop, op, ban

## Detection
- GitHub Secret Scanning alert
- gitleaks pre-commit hook alert
- Audit log shows unexpected RCON_COMMAND events
- Monitoring alert on unusual server commands

## Containment (immediate)
1. Stop the server to prevent further unauthorised commands:
sudo systemctl stop minecraft
2. Rotate the RCON password immediately:
openssl rand -base64 24
sudo nano /etc/minecraft/secrets/rcon
sudo -u minecraft nano /opt/minecraft/homestead/server.properties
3. Restart the server:
sudo systemctl start minecraft
4. Verify new password works:
mc "list"

## Eradication
1. Identify how the credential was exposed
2. If committed to git — contact GitHub Support to scrub the commit
3. Review all RCON commands in audit log during exposure window:
sudo grep "RCON_COMMAND" /var/log/minecraft-audit.json
4. Revoke and rotate any other credentials that may have been co-located

## Recovery
1. Confirm server is running normally
2. Verify no unauthorised ops were granted:
mc "op list"
3. Review whitelist integrity:
mc "whitelist list"
4. Update all systems using the old password (mcrcon alias, monitoring)

## Post-Incident
- Document timeline and exposure window
- Review secrets management procedures
- Consider HashiCorp Vault for secrets if repeated incidents
- Update .gitignore patterns if gap identified

## Evidence to Collect
- Audit log during exposure window
- Git history if committed
- Access logs for any external RCON attempts
