# OPS-001 — Minecraft Exporter Upgrade and Credential Fix (F-001)

## Purpose

Close pentest finding F-001 (RCON password visible in process list) by upgrading
`minecraft-exporter` from v0.6.1 to v0.24.0 and moving the RCON credential from a
CLI argument to the `MC_RCON_PASSWORD` environment variable, which the exporter
reads natively from v0.24.0. Environment variables are not exposed via
`ps aux` or `/proc/<pid>/cmdline`.

Closes threat-model risk R-001 residual exposure. Control references: SOC 2 CC6.1,
ISO 27001 A.9.4.3.

## Preconditions

- SSH access to the Minecraft VPS (port 2222) with sudo.
- `infrastructure/systemd/minecraft_exporter.service` from this repo at the
  version that omits `--mc.rcon-password` (this change ships together with
  this runbook).
- Maintenance window not required — exporter restart does not affect the game
  server; Prometheus will show a brief scrape gap.

## Procedure

### 1. Download and verify the new exporter

```bash
cd /tmp
curl -fsSLO https://github.com/dirien/minecraft-prometheus-exporter/releases/download/v0.24.0/minecraft-exporter_0.24.0.linux-amd64.tar.gz
curl -fsSLO https://github.com/dirien/minecraft-prometheus-exporter/releases/download/v0.24.0/checksums.txt
grep 'linux-amd64.tar.gz$' checksums.txt | sha256sum -c -
tar -xzf minecraft-exporter_0.24.0.linux-amd64.tar.gz
```

The release also publishes an SBOM (`.sbom.json`) and sigstore attestations —
save the SBOM alongside `docs/sbom.md` evidence if desired.

### 2. Add the env var the exporter expects

Rewrite `/etc/minecraft/secrets/rcon` to exactly two lines — `RCON_PASSWORD`
(read by the status API, audit scripts, and restart script) and
`MC_RCON_PASSWORD` (read by the exporter), both holding the same value. This
is idempotent: running it twice never duplicates lines, unlike an append.

```bash
sudo sh -c '
  set -euo pipefail
  pw=$(grep -m1 "^RCON_PASSWORD=" /etc/minecraft/secrets/rcon | cut -d= -f2-)
  [ -n "$pw" ] || { echo "no RCON_PASSWORD found; aborting" >&2; exit 1; }
  printf "RCON_PASSWORD=%s\nMC_RCON_PASSWORD=%s\n" "$pw" "$pw" > /etc/minecraft/secrets/rcon
'
sudo chmod 640 /etc/minecraft/secrets/rcon
sudo chown root:minecraft /etc/minecraft/secrets/rcon
```

**Prerequisite:** the line-based secrets parsers in `status-api.py` and
`minecraft-online-players.sh` (deployed via the normal pipeline) must be live
before adding the second line — older builds read the whole file as the
password and RCON auth breaks for the API and player metrics.

### 3. Install binary and updated unit

The updated unit file is not part of the Actions deploy tar and the repo is not
cloned on the VPS, so copy it over first. From your workstation, in the repo
root:

```bash
scp -P 2222 infrastructure/systemd/minecraft_exporter.service <admin-user>@mc.geigercapital.us:/tmp/
```

Then on the VPS:

```bash
sudo install -o root -g root -m 0755 /tmp/minecraft-exporter /usr/local/bin/minecraft-exporter
sudo install -o root -g root -m 0644 /tmp/minecraft_exporter.service /etc/systemd/system/minecraft_exporter.service
sudo systemctl daemon-reload
sudo systemctl restart minecraft_exporter
```

### 4. Validate

```bash
# Service healthy
systemctl status minecraft_exporter --no-pager

# Password NOT in the process list (expect no output from the grep)
ps -o args= -C minecraft-exporter
ps -o args= -C minecraft-exporter | grep -i rcon-password || echo "PASS: no credential in cmdline"

# Exporter actually listening on 9225 — v0.24.0 ignores the old config-file
# listen-address; the unit must pass --web.listen-address=127.0.0.1:9225
ss -tln | grep 9225
curl -fsS http://127.0.0.1:9225/metrics | grep -c '^minecraft'

# RCON consumers still healthy after the secrets-file change
curl -fsS http://127.0.0.1:5000/status | grep '"online": *true'
sudo /usr/local/bin/minecraft-online-players

# RCON socket binds all interfaces at the Minecraft level; confirm the
# firewall still blocks it externally (no ALLOW rule for 25575, default deny)
sudo ufw status verbose | grep -E "Default:|25575"

# Prometheus target up (from the VPS)
curl -fsS http://127.0.0.1:9090/api/v1/targets 2>/dev/null | grep -o '"health":"up"' | head -1
```

v0.6.1 → v0.24.0 spans many releases; verify any Prometheus queries or future
Grafana panels that reference exporter metric names still resolve.

### 5. Clean up

```bash
rm -f /tmp/minecraft-exporter_0.24.0.linux-amd64.tar.gz /tmp/checksums.txt /tmp/minecraft-exporter /tmp/minecraft_exporter.service
```

## Rollback

Reinstall the previous binary and unit (the old unit passed
`--mc.rcon-password=${RCON_PASSWORD}`; restore from git history at tag/commit
prior to this change), then `daemon-reload` + `restart`. The added
`MC_RCON_PASSWORD` line in the secrets file is harmless to older versions.

## Post-change documentation

After validation passes, update in one commit:

- `docs/pentest-report.md` — F-001 status → Remediated, with the `ps` check as evidence.
- `docs/threat-model/threat-model.md` — R-001 → Implemented; RCON STRIDE row
  "Password in plaintext" → Implemented.
- `docs/secrets-management.md` — remove the F-001 Known Limitation.
- `CHANGELOG.md` — note the exporter upgrade under Security.
- `docs/sbom.md` — infrastructure dependency row for minecraft-exporter v0.24.0.
