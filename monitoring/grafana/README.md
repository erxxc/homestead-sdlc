# Grafana Dashboards

Live Grafana runs on the VPS. The `provisioning/` and `dashboards/` directories
contain the version-controlled Parallel Works data source and overview.

## Production location
- Grafana service: `http://localhost:3000` on VPS (restricted, not public)
- Data source: Prometheus (`monitoring/prometheus/prometheus.yml`)

## Managed dashboard

`Parallel Works Overview` covers scrape health, managed service state, CPU,
memory, disk, per-world backup age, and both Minecraft exporters.

## Control reference
- C-018 — Application metrics monitoring
- C-017 — System metrics monitoring (via Node Exporter)
- SOC2 CC7.2, ISO 27001 A.12.1.3, NIST CSF DE.CM-1

## To export dashboards into this dir
In the Grafana UI: Dashboard → Settings → JSON Model → copy to `monitoring/grafana/homestead.json`.

Or via API:
```
ssh -L 3000:localhost:3000 vps
curl -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
  http://localhost:3000/api/dashboards/uid/<uid> \
  > monitoring/grafana/homestead.json
```
