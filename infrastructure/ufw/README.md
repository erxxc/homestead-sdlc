# UFW Firewall Rules

Live configuration runs on the VPS — this directory is a structural placeholder.

## Production location
- Rule files: `/etc/ufw/` (VPS)
- Active rules: `sudo ufw status verbose` on the VPS

## Allowed ports
See `docs/threat-model/threat-model.md` → Attack Surface → Network Ports for the canonical list. Briefly:

| Port | Protocol | Service |
|---|---|---|
| 2222 | TCP | SSH |
| 25565 | TCP | Minecraft |
| 24454 | UDP | Voice Chat |
| 80 | TCP | Nginx |

Localhost-only (RCON 25575, BlueMap 8100) and monitoring ports (Grafana 3000, Prometheus 9090) are blocked at the public interface by UFW + the Hetzner network firewall.

## Control reference
- C-005 — Dual firewall layer (UFW + Hetzner)
- SOC2 CC6.6, ISO 27001 A.13.1.1, NIST CSF PR.AC-5

## To export current rules into this dir
```
ssh vps "sudo ufw status verbose" > infrastructure/ufw/rules.txt
ssh vps "sudo cat /etc/ufw/user.rules" > infrastructure/ufw/user.rules
```
