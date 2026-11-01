# OPS-008 — Reversible Modpack Profile Switching

## Purpose

Run long-lived and one-off modpacks from two stable public slots without
discarding previous releases. The `mc` slot serves TCP 25565 and the `sb` slot
serves TCP 25566. Every release keeps an isolated runtime, world, Java profile,
logs, and integrity baseline. Switching a slot changes a symlink only after a
verified backup, and automatically restores the prior target if startup fails.

Parallel Works is the public operating brand. All of Create, Homestead, and
SkyFactory 4 are world products within it; future packs receive their own world
page, status route, connection address, and isolated runtime rather than
becoming a rename of the platform.

The first alternate profile is SkyFactory 4 version 4.2.4: Minecraft 1.12.2 on
Forge. It is a legacy pack and must use a separately pinned Java 8 runtime. It
must never open the Fabric 1.20.1 Homestead world.

## Layout

```text
/opt/minecraft/releases/homestead/1.3.6/  # retained; render cache omitted
/opt/minecraft/releases/homestead/2.0.1/  # retained primary rollback
/opt/minecraft/releases/skyfactory4/4.2.4/
/opt/minecraft/releases/all-of-create/2.6/ # active primary release
/opt/minecraft/slots/mc -> ../releases/all-of-create/2.6
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

## World ownership

Worlds belong to releases, not to public addresses or slots. Changing `mc` or
`sb` selects the target release's complete runtime and its own `world/`
directory; the switcher never copies or converts another release's world.

| Release | World path | Current state |
| --- | --- | --- |
| Homestead 1.3.6 | `/opt/minecraft/releases/homestead/1.3.6/world` | Retained, disabled |
| Homestead 2.0.1 | `/opt/minecraft/releases/homestead/2.0.1/world` | Retained, primary rollback |
| SkyFactory 4.2.4 | `/opt/minecraft/releases/skyfactory4/4.2.4/world` | Retained; `sb` paused |
| All of Create 2.6 | `/opt/minecraft/releases/all-of-create/2.6/world` | Active on `mc` |

The final pre-2.0 Homestead reference archive is stored outside normal backup
retention under `/opt/minecraft/archive/homestead-pre-2.0-*/`. The retained
1.3.6 BlueMap render cache was removed because it is regenerable; its world,
configuration, mods, integrity baseline, and reference archive remain.

## Current concurrent safety properties

- Profile files must be root-owned and not group/world writable.
- The concurrent services use separate ports, runtime directories, and worlds.
- The target profile is validated before launch.
- Releases never share a world or backup directory.
- The active `mc` release binds TCP 25565 and RCON 25575; the `sb` release uses
  TCP 25566 and RCON 25576 when enabled. Both RCON ports remain denied at the
  host and provider firewalls.

## Registering another release

1. Put the reviewed runtime under
   `/opt/minecraft/releases/<family>/<version>`. Record the source URL, release
   version, archive SHA-256, Minecraft version, loader, and required Java.
2. Review downloaded installers before running them, execute pack setup as the
   unprivileged `minecraft` user, and keep `online-mode=true`.
3. Give the release its own `world/`, logs, configuration, mod checksum
   baseline, and pack-specific Java executable. Never copy a world or player
   data from another release.
4. Create `.parallel-works-slot` containing exactly `mc` or `sb`, plus a
   root-owned, non-writable `.parallel-works-profile.env`. The profile must use
   the stable compatibility path and port pair for its slot: `25565`/`25575`
   for `mc`, or `25566`/`25576` for `sb`.
5. Confirm enough disk exists for the extracted release, its expected world,
   the configured retained backups, and one in-progress backup. Confirm the
   host can run the target alongside the other active slot without swap or OOM
   pressure.
6. Boot twice in staging and validate the exact protocol, world generator,
   public authentication, RCON isolation, startup logs, exporter, status API,
   backup, verification, restore drill, and automatic rollback.
7. Register any new service, API route, monitoring labels, site page, DNS, and
   firewall rule before advertising the release.

## All of Create 2.6 primary release

All of Create 2.6 is the selected industrial alternate for the primary `mc`
slot. It runs Minecraft 1.21.1 on NeoForge 21.1.256 with Temurin Java 21. The
pack includes Create 6.0.10, Create: New Age's quested nuclear progression,
Power Grid, Electro Energetics, and the pack's supported performance mods.

The installer pins and verifies both upstream artifacts before use:

| Artifact | SHA-256 |
| --- | --- |
| `All_of_Create_v2.6_serverpack.zip` | `62d50ce36847068ecb40e1653f2f5e3bfedf8c8d4daffbb645055536e21b67d0` |
| `neoforge-21.1.256-installer.jar` | `4aad931e8fd85fbf6ba35bab647811069d35ff010900492e39db1cb8b017348c` |

The upstream ServerPackCreator scripts are retained read-only for provenance,
but are not executed. This removes their floating `latest` dependency and
Java installer pipe-to-shell path. The pinned NeoForge installer runs as the
unprivileged `minecraft` account. The resulting release has an immutable mod
checksum baseline and a root-owned slot profile.

Install the release without starting it:

```bash
sudo ACCEPT_MINECRAFT_EULA=TRUE bash /tmp/aoc-deploy/infrastructure/install-all-of-create-v2.6.sh
```

The staging unit conflicts with SkyFactory because the host has 15 GiB RAM and
cannot safely run all three packs together. During validation, Homestead stayed
online while the test stopped SkyFactory and used the same 6 GiB service memory
ceiling. Staging bound only `127.0.0.1:25567`; RCON used 25577 and remained
inaccessible from the network.

```bash
sudo bash /tmp/aoc-deploy/infrastructure/validate-all-of-create-v2.6.sh
```

The gate performed two clean boots, checked that Homestead stayed active,
rejected a non-loopback game listener, scanned the server log for terminal
startup errors, and created and read back a world archive. The successful run
left All of Create running on loopback and SkyFactory stopped. The staging unit
was then stopped before promotion.

```bash
sudo systemctl stop minecraft-all-of-create-staging.service
```

All of Create 2.6 was promoted to `mc` on November 1, 2026 after the generic
primary unit was validated against Homestead, the candidate listener pair was
changed to 25565/25575, and a final Homestead backup was created and verified.
The guarded switch and post-start checks passed. Homestead 2.0.1 remains
unchanged, and the exact rollback command is:

```bash
sudo /usr/local/sbin/minecraft-slot-switch mc homestead/2.0.1
```

Install the guarded switcher and shared profile validation through the normal
deployment workflow. For a manual recovery install:

```bash
sudo install -o root -g root -m 0755 infrastructure/minecraft-profile-validate.sh /usr/local/bin/minecraft-profile-validate
sudo install -o root -g root -m 0755 infrastructure/minecraft-slot-switch.sh /usr/local/sbin/minecraft-slot-switch
```

SkyFactory was originally prepared with the pinned installer below. It records
EULA acceptance, verifies the official 4.2.4 archive against SHA-256
`72b1bae61cbd6a07ab55d71f9e1a94239a4992f35a7f9f4a149e4f1eea04a16b`,
and uses a separate Temurin 8 executable:

```bash
sudo ACCEPT_MINECRAFT_EULA=TRUE /tmp/install-skyfactory4.sh
```

The original installer predates the release-slot layout. Move a prepared
runtime into the release store and add its slot metadata before using the
switcher; do not run the installer over a registered release.

## Staging gate

SkyFactory passed two clean boots, protocol and version checks, public DNS and
TCP reachability checks, memory checks, and isolation checks against the live
Homestead service. BlueMap support for this legacy Forge pack is out of scope.
The SkyFactory status endpoint reports `map_available: false`. SkyFactory is
currently paused while All of Create uses the primary slot.

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
preferably restricted to the players' public IP addresses. Stopping the `sb`
service closes the process listener; remove the allowance if that slot will no
longer host a public pack.

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
`stop`, `restart`, or `status`. The `mc` release remains active during each
action. Players use `mc.geigercapital.us` for All of Create and
`sb.geigercapital.us` for SkyFactory when the secondary slot is enabled.

## Release switch commands

The switcher accepts only registered releases under `/opt/minecraft/releases`.
It serializes changes with a lock, takes and verifies a backup, validates
root-owned release metadata, stops the affected service, changes the slot and
compatibility links, and rolls back after a failed target health check.

```bash
sudo /usr/local/sbin/minecraft-slot-switch mc homestead/1.3.6
sudo /usr/local/sbin/minecraft-slot-switch mc homestead/2.0.1
sudo /usr/local/sbin/minecraft-slot-switch mc all-of-create/2.6
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
runtime for a later session. The active `mc` release continues running
throughout.

The All of Create landing page reads `/status`; the SkyFactory page reads
`/status/skyfactory4`. Each page therefore reports its own service, player
count, version, address, and map availability. The Homestead page records its
retained rollback state without presenting stale live data.
