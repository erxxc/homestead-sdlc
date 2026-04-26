# Nmap Scan Summary

## Date
2026-04-26

## Target
Hetzner VPS — Homestead SMP

## Open Ports (TCP Full Scan)
| Port | Service | Notes |
|---|---|---|
| 80 | HTTP (Nginx) | BlueMap reverse proxy |
| 2222 | SSH (OpenSSH 9.6p1) | Non-standard port |
| 8100 | BlueMap | Remediated — now filtered |
| 25565 | Minecraft 1.20.1 | Game server |

## Open Ports (UDP)
| Port | State | Service |
|---|---|---|
| 24454 | open/filtered | Voice chat |
| 25565 | open/filtered | Minecraft |
| 25575 | open/filtered | RCON (false positive — TCP only) |

## Key Findings
- 65531 ports filtered — minimal attack surface
- RCON (25575 TCP) not externally accessible — localhost only confirmed
- Monitoring ports (3000, 9090, 9100) not externally accessible
- Port 8100 remediated during test — now filtered

## Notes
Full scan output retained locally — not committed to public repo per security best practice.
