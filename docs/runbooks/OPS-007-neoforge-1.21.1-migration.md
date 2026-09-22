# OPS-007 — NeoForge 1.21.1 Parallel Migration

## Purpose

Build a fresh Minecraft 1.21.1 NeoForge world while the Fabric 1.20.1
Homestead server remains the production and rollback instance. Preserve
community access, operational controls, selected configuration, and feature
parity without carrying incompatible mod data into the new pack.

The complete old runtime stays at `/opt/minecraft/homestead`. Never open its
world with Minecraft 1.21.1. Rollback restores the old service definitions and
starts that untouched directory.

## Promotion gates

1. A complete, verified final Homestead backup exists.
2. The old service and supporting units have rollback copies.
3. The new pack boots twice with its fresh world and no registry or data errors.
4. Desired gameplay features have dispositions in the feature matrix.
5. Backup, audit, metrics, map, restart, alerting, integrity, and status controls
   point to the new instance and pass validation.
6. Cutover and rollback have been rehearsed on staging ports.

## What to retain

| Source | Treatment |
|---|---|
| Entire `/opt/minecraft/homestead` instance | Freeze as the rollback runtime |
| Final Homestead world backup | Keep verified and read-only; do not import |
| `whitelist.json`, `ops.json`, `banned-*.json` | Copy after review to preserve UUID-based access decisions |
| `server.properties` | Rebuild; transfer reviewed policy and gameplay values only |
| Player inventories, positions, advancements, statistics | Start fresh unless a separate conversion is approved |
| Configs, scripts, datapacks, and recipes | Behavioral references; port compatible, desired behavior only |
| Claims, teams, quests, homes, waystones, mod dimensions | Start fresh; record replacements in the matrix |
| BlueMap presentation and selected markers | Reapply; render the new world from scratch |
| Monitoring, backup, audit, alert, restart, security controls | Retarget and validate |
| Old mods, loader files, caches, launch scripts | Retain only inside the frozen old instance |

Use `docs/migrations/1.21.1-neoforge-preservation-matrix.md` to match
player-facing capabilities rather than assuming the same Fabric mods must
exist on NeoForge. Operational capabilities remain promotion blockers.

## Isolated staging

Use separate runtime, backup, secret, log, and service paths:

```text
/opt/minecraft/neoforge-1.21.1/
/opt/minecraft/backups-neoforge/
/etc/minecraft/secrets/neoforge-rcon
/etc/systemd/system/minecraft-neoforge-staging.service
```

Use these staging network values:

```properties
server-ip=127.0.0.1
server-port=25566
enable-rcon=true
rcon.port=25576
online-mode=true
white-list=true
enable-status=false
level-name=world
```

Do not add firewall rules for staging. Connect a test client through:

```bash
ssh -p 2222 -L 25566:127.0.0.1:25566 eric@mc.geigercapital.us
```

NeoForge 1.21.1 requires Java 21, which is already installed. Pin and checksum
the server pack, installer, and mod artifacts before execution.

## New-world validation

- Two clean boots complete without registry, datapack, recipe, tag, or config
  errors.
- Spawn, Nether, End, and intended modded dimensions work.
- Whitelist enforcement and representative player UUIDs work.
- Selected progression, storage, automation, claims, teams, quests, voice,
  map, and administration features behave as intended.
- Tick rate, heap use, startup time, and save time are recorded under load.
- Staging remains loopback-only and absent from both firewall allowlists.
- Backups can be created, verified, pruned, and restored.
- Audit, metrics, status, restart, integrity, and failure alerts use new paths.

## Prepare rollback artifacts

Run as `eric` before cutover:

```bash
sudo install -o root -g root -m 0644 /etc/systemd/system/minecraft.service /etc/systemd/system/minecraft-homestead.service.rollback
sudo install -o root -g root -m 0644 /etc/systemd/system/minecraft-audit.service /etc/systemd/system/minecraft-audit-homestead.service.rollback
sudo install -o root -g root -m 0644 /etc/systemd/system/minecraft_exporter.service /etc/systemd/system/minecraft_exporter-homestead.service.rollback
sudo install -o root -g root -m 0644 /etc/systemd/system/minecraft-backup.service /etc/systemd/system/minecraft-backup-homestead.service.rollback
sudo sha256sum /etc/systemd/system/*-homestead.service.rollback | sudo tee /etc/minecraft/homestead-rollback.sha256
```

Store reviewed new-instance equivalents as:

```text
/etc/systemd/system/minecraft-neoforge.service.candidate
/etc/systemd/system/minecraft-audit-neoforge.service.candidate
/etc/systemd/system/minecraft_exporter-neoforge.service.candidate
/etc/systemd/system/minecraft-backup-neoforge.service.candidate
```

Each candidate must use `/opt/minecraft/neoforge-1.21.1` and its dedicated
world, logs, secrets, and backup directory.

## Cut over

During the approved maintenance window, stop readers and then the old game:

```bash
sudo systemctl stop minecraft-audit minecraft_exporter
sudo systemctl stop minecraft
sudo /usr/local/bin/verify-backup
```

Install the candidates and start the new stack:

```bash
sudo install -o root -g root -m 0644 /etc/systemd/system/minecraft-neoforge.service.candidate /etc/systemd/system/minecraft.service
sudo install -o root -g root -m 0644 /etc/systemd/system/minecraft-audit-neoforge.service.candidate /etc/systemd/system/minecraft-audit.service
sudo install -o root -g root -m 0644 /etc/systemd/system/minecraft_exporter-neoforge.service.candidate /etc/systemd/system/minecraft_exporter.service
sudo install -o root -g root -m 0644 /etc/systemd/system/minecraft-backup-neoforge.service.candidate /etc/systemd/system/minecraft-backup.service
sudo systemctl daemon-reload
sudo systemctl start minecraft
sudo systemctl start minecraft-audit minecraft_exporter
sudo systemctl is-active minecraft minecraft-audit minecraft_exporter
```

Validate the game, new world, status, metrics, map, listeners, backup target,
and audit events before opening the whitelist.

## Roll back to Homestead

Stop new-world writers first:

```bash
sudo systemctl stop minecraft-audit minecraft_exporter
sudo systemctl stop minecraft
```

Verify and restore the frozen Homestead units:

```bash
sudo sha256sum -c /etc/minecraft/homestead-rollback.sha256
sudo install -o root -g root -m 0644 /etc/systemd/system/minecraft-homestead.service.rollback /etc/systemd/system/minecraft.service
sudo install -o root -g root -m 0644 /etc/systemd/system/minecraft-audit-homestead.service.rollback /etc/systemd/system/minecraft-audit.service
sudo install -o root -g root -m 0644 /etc/systemd/system/minecraft_exporter-homestead.service.rollback /etc/systemd/system/minecraft_exporter.service
sudo install -o root -g root -m 0644 /etc/systemd/system/minecraft-backup-homestead.service.rollback /etc/systemd/system/minecraft-backup.service
sudo systemctl daemon-reload
sudo systemctl start minecraft
sudo systemctl start minecraft-audit minecraft_exporter
```

Confirm the restored runtime:

```bash
sudo systemctl is-active minecraft minecraft-audit minecraft_exporter
sudo systemctl show minecraft -p WorkingDirectory -p ExecStart --no-pager
curl -fsS http://127.0.0.1:5000/status
curl -fsS -o /dev/null https://map.geigercapital.us/
sudo ss -lntup | grep -E ':(25565|25575|8100|9225)\b'
```

The restored working directory must be `/opt/minecraft/homestead`. Keep the
failed NeoForge world for diagnosis, but never run both instances on production
ports.
