# Observability

## Stack

Monitoring is deployed with `kube-prometheus-stack` and includes:

- Prometheus
- Alertmanager
- Grafana

The workload provides:

- `/metrics` endpoint
- ServiceMonitor for scraping
- PrometheusRules for SLO-style alerting
- Grafana dashboard auto-provisioned via sidecar

## URLs

- Grafana: <http://grafana.127.0.0.1.nip.io>
- Alertmanager: <http://alertmanager.127.0.0.1.nip.io>

## Dashboard

`Player Data Service - SLO` dashboard supports namespace filtering:

- `player-data-dev`
- `player-data-staging`
- `player-data-prod`

Main panels:

- request rate
- p95 latency
- availability

## Alerting

Base alerts (all environments, namespace-scoped by overlay patches):

- `PlayerDataServiceHigh5xxRatio`
- `PlayerDataServiceHighP95Latency`
- `PlayerDataServiceLowAvailability`

Demo alert (dev only):

- `PlayerDataServiceDevHighCpuDemo`
- condition: CPU usage > 90% of limit for 30s
- used for demonstrable alert triggering in assignment context

By default, Alertmanager has no external receiver configured (UI only).

## Demo commands

Run full demo:

```bash
bash infra/scripts/demo-monitoring.sh full-demo 120
```

What it does:

- starts temporary CPU burn job in `player-data-dev`
- generates traffic on all 3 environments
- lets you observe Grafana changes and Alertmanager alert
