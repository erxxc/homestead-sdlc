# Security evidence refresh — 2026-09-24

## Result

The external exposure, public web controls, CI security workflows, custom
service hardening, monitoring, and recovery controls were rechecked after the
September operations work. No unexpected public listener or failed security
workflow was found.

## External TCP exposure

Targeted TCP scan of the documented service ports against the VPS public
address:

| Result | Ports |
|---|---|
| Open and intended | 80, 443, 2222, 25565, 25566 |
| Filtered | 22, 3000, 3001, 5000, 8100, 9090, 9093, 9100, 9225, 9226, 25575, 25576 |

Grafana, Uptime Kuma, the status API, BlueMap origin, Prometheus,
Alertmanager, Node Exporter, both Minecraft exporters, and both RCON ports were
not reachable directly from the Internet. The two game ports, HTTPS/HTTP, and
the nonstandard SSH port were reachable as designed.

## Web edge

- `play.geigercapital.us`, `api.geigercapital.us/health`, and
  `map.geigercapital.us` returned HTTP 200 to GET.
- The map continues to return HTTP 400 to HEAD, a documented BlueMap behavior;
  availability monitors use GET.
- The site and API returned HSTS, CSP, MIME-sniffing, frame, permissions, and
  referrer protections.
- `ops.geigercapital.us` and `status-admin.geigercapital.us` redirected an
  unauthenticated request to Cloudflare Access.

## CI evidence

For commit `59ca3019ddf6736ecd5bbb0776d442b8bbdb43f2`:

- CodeQL: success
- Checkov: success
- Lint and tests: success
- ZAP DAST: success
- VPS deployment: success

## Runtime hardening and recovery

- Status API systemd exposure: 3.2 `OK` (previously 9.2 `UNSAFE`)
- Audit logger systemd exposure: 2.8 `OK` (previously 9.2 `UNSAFE`)
- Mod watcher systemd exposure: 2.8 `OK` (previously 9.2 `UNSAFE`)
- Both game services remained active through the hardening change.
- Homestead and SkyFactory full-extraction restore drills passed and removed
  their disposable scratch directories.
- Prometheus SLO rules and Loki log rules were loaded without evaluation
  failures; ntfy firing/resolved delivery and the weekly digest were confirmed.

## Residual items

- Volumetric Minecraft traffic remains an upstream/provider risk; generic
  per-IP UFW limiting was rejected because it can disrupt shared-NAT players
  without preventing link saturation.
- Chat content retention remains a privacy and policy decision. Session and
  administrative security events are logged, while chat text is not.
- Reviewed configuration paths have not yet been selected for the optional
  configuration-integrity baseline.
- GitHub 2FA status requires account-owner confirmation and is not asserted by
  this technical evidence run.

## Repeatability

Run `security/collect-security-evidence.sh` from an authorized workstation to
produce a timestamped, mode-0700 evidence directory and checksum manifest. The
collector excludes credentials and does not modify the VPS.
