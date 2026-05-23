# fail2ban

Live configuration runs on the VPS — this directory is a structural placeholder.

## Production location
- Jail config: `/etc/fail2ban/jail.local` (VPS)
- Status: `sudo fail2ban-client status` and `sudo fail2ban-client status sshd`

## Protection scope
- SSH brute-force on port 2222 — sshd jail enabled
- Backed by `/var/log/auth.log` log scraping

## Control reference
- C-004 — fail2ban brute force protection
- SOC2 CC6.1 / CC7.2, ISO 27001 A.9.4.2, NIST CSF DE.CM-1
- Threat model row: SSH component, "Brute force credential attack"
- Pentest report — listed under positive findings

## To export current config into this dir
```
ssh vps "sudo cat /etc/fail2ban/jail.local" > security/fail2ban/jail.local
ssh vps "sudo fail2ban-client status sshd" > security/fail2ban/status.txt
```
