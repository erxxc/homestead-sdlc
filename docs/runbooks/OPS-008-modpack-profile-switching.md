# OPS-008 — Reversible Modpack Profile Switching

## Purpose

Run short-lived modpacks on the production Minecraft address without replacing
or upgrading the Homestead runtime. Every pack has an isolated runtime, world,
backup set, Java executable, logs, and integrity baseline. Only one profile may
own the production game and RCON ports at a time.

The first alternate profile is SkyFactory 4 version 4.2.4: Minecraft 1.12.2 on
Forge. It is a legacy pack and must use a separately pinned Java 8 runtime. It
must never open the Fabric 1.20.1 Homestead world.

## Layout

```text
/opt/minecraft/homestead/                 # existing Fabric runtime; unchanged
/opt/minecraft/skyfactory4-4.2.4/         # isolated Forge runtime and world
/opt/minecraft/backups/homestead/
/opt/minecraft/backups/skyfactory4/
/etc/minecraft/profiles/homestead.env
/etc/minecraft/profiles/skyfactory4.env
/etc/minecraft/active-profile             # root-owned symlink to one profile
/etc/minecraft/secrets/rcon                # existing secret; never in profiles
```

The active profile is configuration, not a copy operation. Switching changes
one symlink while both runtime trees remain in place.

## Safety properties

- The switch refuses unknown profile names and concurrent switches.
- Profile files must be root-owned and not group/world writable.
- A world-consistent backup and verification run before the active server stops.
- Audit, exporter, and status readers stop before the game process.
- The target profile is validated before launch.
- Failed startup or health checks restore the previous profile automatically.
- Homestead and SkyFactory never share a world or backup directory.
- The production firewall remains unchanged; only the active profile binds
  ports 25565 and 25575.

## One-time preparation

1. Install a supported Temurin 8 runtime alongside Java 21. Do not change the
   system default Java; the SkyFactory profile uses an absolute executable.
2. Download the official SkyFactory 4 4.2.4 **server files** from CurseForge.
   Record the source URL and SHA-256 before extracting as `minecraft`.
3. Run the pack's server installation process in the isolated directory. Review
   its scripts before execution and do not run downloaded installers as root.
4. Preserve the pack's intended SkyFactory world-generation configuration.
   Boot on loopback staging ports first and confirm it creates a skyblock world,
   not a normal overworld.
5. Set `online-mode=true`, `white-list=true`, RCON on loopback-protected port
   25575, and copy only reviewed UUID access lists. Do not copy player data.
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

Before the first production switch, start SkyFactory on an alternate
ports and verify two clean boots, the correct world type, whitelist behavior,
RCON, backup/restore, logs, memory use, and mod integrity. BlueMap support for
this legacy Forge pack is out of scope. The SkyFactory profile sets
`MC_MAP_MODE=offline`; the API reports `map_available: false`, the landing page
marks the map offline, and the map vhost serves the intentional offline page.
The Homestead profile restores BlueMap automatically.

Use the manual `SkyFactory Staging Control` workflow to start, stop, restart,
or inspect the staging service. It asserts that Homestead remains the
active production service and waits for port 25566 before declaring startup
successful. The game listener binds to TCP 25566 for direct client tests.
Staging uses online authentication without a whitelist to match Homestead;
RCON 25576 must remain blocked at both firewall layers.

```bash
sudo ufw allow 25566/tcp comment 'Temporary SkyFactory staging'
```

Add the same TCP 25566 inbound allowance to the Hetzner firewall, preferably
restricted to the players' public IP addresses. Remove both allowances after
the session; stopping the staging workflow also closes the process listener.

Cloudflare DNS provides a short, port-free client address. These records must
remain **DNS only** because the standard Cloudflare proxy does not carry the
Minecraft protocol:

| Type | Name | Target / content | Port |
| --- | --- | --- | --- |
| CNAME | `sb` | `mc.geigercapital.us` | — |
| SRV | `_minecraft._tcp.sb` | `sb.geigercapital.us` | `25566` |

Set SRV priority and weight to `0`. Players can then enter
`sb.geigercapital.us`; Minecraft discovers TCP 25566 through the SRV record.

## Switch commands

After every consumer passes the staging gate:

```bash
sudo /usr/local/sbin/minecraft-profile-switch skyfactory4
```

Return to the untouched Homestead runtime with:

```bash
sudo /usr/local/sbin/minecraft-profile-switch homestead
```

Confirm the selected profile and public health after either command:

```bash
readlink -f /etc/minecraft/active-profile
systemctl is-active minecraft minecraft-audit minecraft_exporter minecraft-status-api
systemctl show minecraft -p MainPID -p ExecMainStartTimestamp --no-pager
curl -fsS http://127.0.0.1:5000/status
```

## Session closeout

Switch back to Homestead, verify its latest backup, confirm the Homestead world
and pack version through the status API, and retain the SkyFactory runtime and
backups. A later session can reactivate it without reinstalling or moving data.

The landing page follows the API's active profile. It redirects to the
SkyFactory session page while `MC_PROFILE=skyfactory4`, retaining live status,
player counts, version reporting, and links to the exact client pack. Returning
to Homestead returns visitors to the normal landing page.
