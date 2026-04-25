# Software Bill of Materials — Homestead SDLC PoC

## Minecraft Server
| Component | Version | Source |
|---|---|---|
| Minecraft Java Edition | 1.20.1 | Mojang (official) |
| Fabric Loader | 0.18.6 | fabricmc.net |
| Fabric API | 0.92.7+1.20.1 | Modrinth |

## Mod Sources
| Source | Count | Verification |
|---|---|---|
| Modrinth (mrpack) | ~290 | SHA-256 checksum |
| CurseForge (manual transfer) | 6 FTB mods | SHA-256 checksum |
| Manual compilation | 0 | N/A |

## FTB Mods (CurseForge — manual transfer)
| Mod | Version | Transfer Date |
|---|---|---|
| ftb-essentials-fabric | 2001.2.3 | 2026-04-12 |
| ftb-filter-system-fabric | 1.0.2 | 2026-04-12 |
| ftb-library-fabric | 2001.2.9 | 2026-04-12 |
| ftb-quests-fabric | 2001.4.13 | 2026-04-12 |
| ftb-teams-fabric | 2001.3.1 | 2026-04-12 |
| ftb-xmod-compat-fabric | 2.1.2 | 2026-04-12 |

## Integrity Controls
- SHA-256 checksums generated for all mod jars
- Checksum file stored at /opt/minecraft/homestead/mod_checksums.sha256
- Automated verification runs as systemd ExecStartPre on every server start
- Any checksum failure stops the server and logs to /var/log/minecraft-integrity.log
- Checksum baseline regenerated after any approved mod addition or update

## Infrastructure Dependencies
| Component | Version | Source |
|---|---|---|
| Ubuntu | 24.04 LTS | Hetzner |
| Java | Temurin 21 | Adoptium |
| Nginx | Latest | apt |
| fail2ban | Latest | apt |
| Lynis | Latest | apt |
