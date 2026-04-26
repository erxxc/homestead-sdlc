# IR-001 — Player Account Compromise

## Trigger
- Player reports inability to log in
- Unusual activity from a known player account
- Player reports their Minecraft account was hacked

## Severity
High — compromised account can grief builds, steal items, damage player relationships

## Detection
- Audit log shows unusual login times or locations
- Players report suspicious behaviour from known username
- Minecraft account holder reports compromise to admin

## Containment (immediate)
1. Ban the account immediately:
mc "ban PlayerUsername Account compromised — contact admin to resolve"
2. Check what the account did recently:
sudo grep "PlayerUsername" /opt/minecraft/homestead/logs/latest.log | tail -50
3. Notify other online players if griefing occurred

## Eradication
1. Player must secure their Minecraft account via Mojang/Microsoft account portal
2. Enable 2FA on their Microsoft account
3. Verify account ownership before unbanning

## Recovery
1. Unban once account is secured:
mc "pardon PlayerUsername"
2. Assess and restore any grief damage using world backup if needed:
sudo systemctl stop minecraft
sudo -u minecraft tar -xzf /opt/minecraft/backups/[backup-file].tar.gz
sudo systemctl start minecraft
3. Document incident in incident log

## Post-Incident
- Review audit logs for full scope of damage
- Update player communication guidelines
- Consider whitelist if repeated incidents

## Evidence to Collect
- Audit log entries during compromise window
- Server log for actions taken by the account
- Backup timestamps for recovery reference
