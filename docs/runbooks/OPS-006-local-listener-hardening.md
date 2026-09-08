# OPS-006 — Local Listener Hardening

## Purpose

Reduce the VPS attack surface by binding administrative and reverse-proxied
services to loopback. Public play requires only Minecraft TCP 25565, Simple
Voice Chat UDP 24454, SSH TCP 2222, and Nginx TCP 80/443.

RCON is part of the Minecraft process and does not have an independent bind
address. Keep TCP 25575 denied at both UFW and the Hetzner firewall. Do not set
`server-ip=127.0.0.1`: that would also bind the game listener to loopback and
prevent players from connecting.

## Preflight

Open two SSH sessions so one remains available if a configuration check fails.
Record the current listeners and firewall policy:

```bash
sudo ss -lntup
sudo ufw status numbered
```

The allowlist should contain TCP 2222, 80, 443, and 25565 plus UDP 24454. It
must not allow TCP 25575, 8100, 3000, 3001, 9090, 9100, or 9225.

## Bind Uptime Kuma to loopback

The repo-managed unit sets `UPTIME_KUMA_HOST=127.0.0.1`. Install the updated
unit, reload systemd, and restart Kuma:

```bash
sudo install -o root -g root -m 0644 infrastructure/systemd/uptime-kuma.service /etc/systemd/system/uptime-kuma.service
sudo systemctl daemon-reload
sudo systemctl restart uptime-kuma
curl -fsS -o /dev/null http://127.0.0.1:3001/
```

## Bind Grafana to loopback

Run as the `eric` administrative account. The command creates a dated backup,
sets the existing `http_addr` entry, and restores the package configuration's
expected `root:grafana` ownership:

```bash
sudo cp -a /etc/grafana/grafana.ini "/etc/grafana/grafana.ini.bak.$(date -u +%Y%m%dT%H%M%SZ)" && sudo sed -i -E 's|^[[:space:]]*;?[[:space:]]*http_addr[[:space:]]*=.*$|http_addr = 127.0.0.1|' /etc/grafana/grafana.ini && sudo chown root:grafana /etc/grafana/grafana.ini
```

Confirm the setting appears once, then restart and validate:

```bash
sudo grep -nE '^[[:space:]]*http_addr[[:space:]]*=' /etc/grafana/grafana.ini
sudo systemctl restart grafana-server
curl -fsS -o /dev/null http://127.0.0.1:3000/login
sudo ss -lntp | grep ':3000\b'
```

## Bind BlueMap to loopback

Run as `eric`. BlueMap's `ip` option is hidden and may not already exist, so
this command replaces it when present or appends it when absent. It creates a
dated backup and restores `minecraft:minecraft` ownership:

```bash
BLUEMAP_WEB=/opt/minecraft/homestead/config/bluemap/webserver.conf; sudo cp -a "$BLUEMAP_WEB" "$BLUEMAP_WEB.bak.$(date -u +%Y%m%dT%H%M%SZ)" && if sudo grep -qE '^[[:space:]]*ip[[:space:]]*:' "$BLUEMAP_WEB"; then sudo sed -i -E 's|^[[:space:]]*ip[[:space:]]*:.*$|ip: "127.0.0.1"|' "$BLUEMAP_WEB"; else printf '\nip: "127.0.0.1"\n' | sudo tee -a "$BLUEMAP_WEB" >/dev/null; fi; sudo chown minecraft:minecraft "$BLUEMAP_WEB"
```

Confirm the setting appears once. Restart Minecraft during a maintenance
window, then confirm Nginx can still reach BlueMap:

```bash
sudo grep -nE '^[[:space:]]*ip[[:space:]]*:' /opt/minecraft/homestead/config/bluemap/webserver.conf
sudo systemctl restart minecraft
curl -fsS -o /dev/null http://127.0.0.1:8100/
curl -fsS -o /dev/null https://map.geigercapital.us/
sudo ss -lntp | grep ':8100\b'
```

## Validate

```bash
sudo ss -lntup | grep -E ':(3000|3001|8100|25575)\b'
sudo ufw status verbose
```

Ports 3000, 3001, and 8100 should show `127.0.0.1`. RCON 25575 may remain a
wildcard listener but must have no firewall allow rule. From a separate host,
25575, 8100, 3000, and 3001 must time out or refuse connections.

Use SSH tunnels for the administrative interfaces:

```bash
ssh -p 2222 -L 3000:127.0.0.1:3000 -L 3001:127.0.0.1:3001 eric@mc.geigercapital.us
```
