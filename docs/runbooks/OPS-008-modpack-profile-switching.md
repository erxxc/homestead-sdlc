# OPS-008 — Reversible Modpack Profile Switching

## Purpose

Run long-lived and one-off modpacks from two stable public slots without
discarding previous releases. The `mc` slot serves TCP 25565 and the `sb` slot
serves TCP 25566. Every release keeps an isolated runtime, world, Java profile,
logs, and integrity baseline. Switching a slot changes a symlink only after a
verified backup, and automatically restores the prior target if startup fails.

Parallel Works is the public operating brand. Homestead and SkyFactory 4 are
world products within it; future packs receive their own world page, status
route, connection address, and isolated runtime rather than becoming a rename
of the platform.

The first alternate profile is SkyFactory 4 version 4.2.4: Minecraft 1.12.2 on
Forge. It is a legacy pack and must use a separately pinned Java 8 runtime. It
must never open the Fabric 1.20.1 Homestead world.

## Layout

```text
/opt/minecraft/releases/homestead/1.3.6/  # retained, normally disabled
/opt/minecraft/releases/homestead/2.0.1/  # active long-lived release
/opt/minecraft/releases/skyfactory4/4.2.4/
/opt/minecraft/slots/mc -> ../releases/homestead/2.0.1
/opt/minecraft/slots/sb -> ../releases/skyfactory4/4.2.4
/opt/minecraft/homestead -> slots/mc      # compatibility path
/opt/minecraft/skyfactory4-4.2.4 -> slots/sb
/opt/minecraft/backups/homestead/
/opt/minecraft/backups/skyfactory4/
/etc/minecraft/profiles/homestead.env
/etc/minecraft/profiles/skyfactory4-staging.env
/etc/minecraft/secrets/rcon                # existing secret; never in profiles
```

Existing systemd units and operational collectors continue to use the two
compatibility paths. This keeps service hardening, exporters, backup jobs,
status APIs, and public addresses stable while the slot targets change.

## Current concurrent safety properties

- Profile files must be root-owned and not group/world writable.
- The concurrent services use separate ports, runtime directories, and worlds.
- The target profile is validated before launch.
- Homestead and SkyFactory never share a world or backup directory.
- Homestead binds TCP 25565 and RCON 25575; SkyFactory binds TCP 25566 and RCON
  25576. Both RCON ports remain denied at the host and provider firewalls.

## One-time preparation

1. Install a supported Temurin 8 runtime alongside Java 21. Do not change the
   system default Java; the SkyFactory profile uses an absolute executable.
2. Download the official SkyFactory 4 4.2.4 **server files** from CurseForge.
   Record the source URL and SHA-256 before extracting as `minecraft`.
3. Run the pack's server installation process in the isolated directory. Review
   its scripts before execution and do not run downloaded installers as root.
4. Preserve the pack's intended SkyFactory world-generation configuration and
   confirm it creates a skyblock world, not a normal overworld.
5. Set `online-mode=true`. The current private group mirrors Homestead with
   `white-list=false`; enable and populate a UUID whitelist before widening the
   audience. Never copy player data between worlds.
6. Generate a dedicated mod checksum baseline for the SkyFactory directory.
7. Install the scripts, unit, and reviewed profile files:

```bash
sudo install -o root -g root -m 0755 infrastructure/minecraft-profile-launch.sh /usr/local/bin/minecraft-profile-launch
sudo install -o root -g root -m 0755 infrastructure/minecraft-profile-validate.sh /usr/local/bin/minecraft-profile-validate
sudo install -o root -g root -m 0755 infrastructure/minecraft-profile-switch.sh /usr/local/sbin/minecraft-profile-switch
sudo install -o root -g root -m 0644 infrastructure/systemd/minecraft-profile.service /etc/systemd/system/minecraft.service
sudo install -d -o root -g root -m 0755 /etc/minecraft/profiles
sudo install -o root -g root -m 0644 infrastructure/profiles/homestead.env.example /etc/minecraft/profiles/homestead.env
sudo install -o root -g root -m 0644 infrastructure/profiles/skyfactory4.env.example /etc/minecraft/profiles/skyfactory4.env
sudo ln -sfn /etc/minecraft/profiles/homestead.env /etc/minecraft/active-profile
sudo systemctl daemon-reload
```

The pinned preparation script can perform the Java 8 and server-pack setup
without activating the profile:

```bash
sudo ACCEPT_MINECRAFT_EULA=TRUE /tmp/install-skyfactory4.sh
```

Setting `ACCEPT_MINECRAFT_EULA=TRUE` records the operator's acceptance of the
Minecraft EULA. The script verifies the official 4.2.4 server archive against
SHA-256 `72b1bae61cbd6a07ab55d71f9e1a94239a4992f35a7f9f4a149e4f1eea04a16b`,
uses the absolute Temurin 8 executable, and leaves the pack on its dedicated
staging game port. It does not stop or restart Homestead.

Do not install the generic service until backup, audit, exporter, status API,
restart, integrity, and map consumers have been updated to read the active
profile. Until then this runbook and the profile layer are preparation only.

## Staging gate

SkyFactory passed two clean boots, protocol and version checks, public DNS and
TCP reachability checks, memory checks, and isolation checks against the live
Homestead service. BlueMap support for this legacy Forge pack is out of scope.
The SkyFactory status endpoint reports `map_available: false`; the Homestead
map remains online because both servers are currently running concurrently.

Use the manual `SkyFactory Staging Control` workflow to start, stop, restart,
or inspect the staging service. It asserts that Homestead remains the
active production service and waits for port 25566 before declaring startup
successful. The game listener binds to TCP 25566 for direct client tests.
Staging uses online authentication without a whitelist to match Homestead;
RCON 25576 must remain blocked at both firewall layers.

```bash
sudo ufw allow 25566/tcp comment 'Temporary SkyFactory staging'
```

The same TCP 25566 inbound allowance is required in the Hetzner firewall,
preferably restricted to the players' public IP addresses. Remove both
allowances after the session; stopping the staging workflow also closes the
process listener.

Cloudflare DNS provides a short, port-free client address. These records must
remain **DNS only** because the standard Cloudflare proxy does not carry the
Minecraft protocol:

| Type | Name | Target / content | Port |
| --- | --- | --- | --- |
| CNAME | `sb` | `mc.geigercapital.us` | — |
| SRV | `_minecraft._tcp.sb` | `sb.geigercapital.us` | `25566` |

Set SRV priority and weight to `0`. Players can then enter
`sb.geigercapital.us`; Minecraft discovers TCP 25566 through the SRV record.

## Concurrent control commands

Use the GitHub Actions `SkyFactory Staging Control` workflow with `start`,
`stop`, `restart`, or `status`. Homestead remains active during each action.
Players use `mc.geigercapital.us` for Homestead and `sb.geigercapital.us` for
SkyFactory.

## Release switch commands

The switcher accepts only registered releases under `/opt/minecraft/releases`.
It serializes changes with a lock, takes and verifies a backup, validates
root-owned release metadata, stops the affected service, changes the slot and
compatibility links, and rolls back after a failed target health check.

```bash
sudo /usr/local/sbin/minecraft-slot-switch mc homestead/1.3.6
sudo /usr/local/sbin/minecraft-slot-switch mc homestead/2.0.1
```

SkyFactory remains the registered `sb` release. A future one-off pack prepared
for that slot can be selected with the same command:

```bash
sudo /usr/local/sbin/minecraft-slot-switch sb skyfactory4/4.2.4
```

Confirm the selected profile and public health after either command:

```bash
readlink -f /opt/minecraft/slots/mc /opt/minecraft/slots/sb
systemctl is-active minecraft minecraft-skyfactory4-staging
curl -fsS http://127.0.0.1:5000/status
curl -fsS http://127.0.0.1:5000/status/skyfactory4
```

## Session closeout

Stop the SkyFactory staging service, take and verify a SkyFactory world backup,
remove the TCP 25566 allowances from UFW and Hetzner, and retain the isolated
runtime for a later session. Homestead continues running throughout.

The Homestead landing page reads `/status`; the SkyFactory page reads
`/status/skyfactory4`. Each page therefore reports its own concurrent service,
player count, version, address, and map availability.
