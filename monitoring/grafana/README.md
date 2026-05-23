# Grafana Dashboards

Live Grafana instance runs on the VPS — this directory is a structural placeholder for exported dashboard JSON.

## Production location
- Grafana service: `http://localhost:3000` on VPS (restricted, not public)
- Data source: Prometheus (`monitoring/prometheus/prometheus.yml`)

## Active dashboards
Homestead operational dashboard (6 panels):
- Players online
- Available memory
- CPU usage
- Player playtime
- Disk space
- Player deaths

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
