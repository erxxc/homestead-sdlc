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
| CurseForge client pack (1.3.6) | 427 | SHA-256 checksum |
| Client-only mods removed | 45 | Excluded from server deployment |
| FTB mods (manual transfer) | 6 | SHA-256 checksum |
| Performance mods (Modrinth, gated install) | 5 | SHA-512 at download + SHA-256 baseline |
| Manual compilation | 0 | N/A |

## Performance Mods (server-side, installed 2026-08-13 via OPS-003)

| Mod | Version | Source |
|---|---|---|
| spark | 1.10.53-fabric | Modrinth |
| FerriteCore | 6.0.1 | Modrinth |
| ModernFix | 5.25.2+mc1.20.1 | Modrinth |
| Krypton | 0.2.3 | Modrinth |
| Lithium | mc1.20.1-0.11.4 | Modrinth |

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

- SHA-256 checksums generated for all 427 server-side mod jars
- Checksum file stored at /opt/minecraft/homestead/mod_checksums.sha256
- Automated verification runs as systemd ExecStartPre on every server start
- Any checksum failure stops the server and logs to /var/log/minecraft-integrity.log
- Checksum baseline regenerated after any approved mod addition or update
- Modpack version: Homestead 1.3.6 (1.3.1 → 1.3.4 on 2026-05-02; 1.3.5 and 1.3.6 minor bumps since, no breaking changes)
- Live server version re-verified 2026-08-13 via status API — still Homestead 1.3.6; per-mod inventory snapshot dates from 2026-04-12 and is regenerated on modpack upgrades

## Infrastructure Dependencies

| Component | Version | Source |
|---|---|---|
| Ubuntu | 24.04 LTS | Hetzner |
| Java | Temurin 21 | Adoptium |
| Nginx | Latest | apt |
| fail2ban | Latest | apt |
| Lynis | Latest | apt |
