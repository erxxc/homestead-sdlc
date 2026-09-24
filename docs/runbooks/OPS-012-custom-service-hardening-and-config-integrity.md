# OPS-012 — Custom-service hardening and configuration integrity

## Scope

Apply narrow systemd sandboxes to the status API, audit logger, and mod watcher.
Install an optional boot-time integrity gate for reviewed configuration trees.
The installer restarts only those three custom services; it does not restart a
game server or change a firewall.

## Install

Copy the repository bundle to the VPS and run:

```bash
sudo /tmp/parallel-works-security-hardening/infrastructure/install-custom-service-hardening.sh
```

The installer backs up any existing hardening drop-ins, validates the units,
restarts the three services, checks their active state and API health, and
automatically restores the previous drop-ins if validation fails.

The drop-ins remove capabilities, deny privilege escalation, hide devices and
home directories, make the system read-only, constrain address families, and
grant write access only to each service's required log or state location.

## Configuration integrity

The Minecraft service receives an additional `ExecStartPre` gate. It is a
documented no-op until an operator reviews and populates the root-owned file
`/etc/minecraft/integrity/paths`. Each non-comment line must be an absolute file
or directory below `/opt/minecraft`.

Example for a pack that actually contains KubeJS server scripts:

```bash
sudo install -d -o root -g root -m 0755 /etc/minecraft/integrity
printf '%s\n' '/opt/minecraft/homestead/kubejs/server_scripts' | sudo tee /etc/minecraft/integrity/paths
sudo chown root:root /etc/minecraft/integrity/paths
sudo chmod 0644 /etc/minecraft/integrity/paths
sudo /usr/local/bin/minecraft-config-integrity generate
sudo /usr/local/bin/minecraft-config-integrity verify
```

Review every selected path and its contents before generating the baseline.
The tool refuses paths outside `/opt/minecraft`, symbolic links, missing paths,
and empty baselines. Verification detects additions, removals, and content
changes. The mod watcher also watches configured paths recursively and records
changes for manual review.

## Validate

```bash
systemctl is-active minecraft-status-api minecraft-audit minecraft-mod-watcher
curl -fsS http://127.0.0.1:5000/health
systemd-analyze security minecraft-status-api.service --no-pager
systemd-analyze security minecraft-audit.service --no-pager
systemd-analyze security minecraft-mod-watcher.service --no-pager
sudo /usr/local/bin/minecraft-config-integrity verify
```

## Network-flood decision

The host has TCP SYN cookies and reverse-path filtering enabled, a 4096 accept
queue, host and provider firewall allowlists, and Cloudflare protection for web
traffic. Standard Cloudflare proxying cannot carry Minecraft protocol traffic.

Do not apply generic `ufw limit` to Minecraft ports without a measured test.
It limits new connections per source address, can block legitimate groups
behind shared NAT, and does not stop a volumetric attack from reaching the VPS.
Provider mitigation and a Minecraft-aware proxy are the appropriate future
controls if public-player exposure grows.

## Rollback

```bash
sudo rm -f /etc/systemd/system/minecraft-status-api.service.d/security-hardening.conf
sudo rm -f /etc/systemd/system/minecraft-audit.service.d/security-hardening.conf
sudo rm -f /etc/systemd/system/minecraft-mod-watcher.service.d/security-hardening.conf
sudo rm -f /etc/systemd/system/minecraft.service.d/config-integrity.conf
sudo systemctl daemon-reload
sudo systemctl restart minecraft-status-api minecraft-audit minecraft-mod-watcher
```
