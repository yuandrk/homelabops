# Monitoring

What is collected, where to look, and what does not work yet.

## What runs

| Piece | Details |
|-------|---------|
| Prometheus (kube-prometheus-stack) | On a 10Gi `local-path` volume, amd64 nodes only. Scrapes node-exporter, kube-state-metrics, the Flux controllers and cloudflared (PodMonitors), and Traefik (`additionalScrapeConfigs`, job `traefik`) |
| Grafana | `grafana.yuandrk.net`, local admin from the `grafana-admin-credentials` Secret. Datasources: Prometheus, Loki, and `PostgreSQL-Homelab` (the PostgreSQL on k3s-worker3) |
| Loki | SingleBinary on a 10Gi `local-path` volume on k3s-worker3, caches off. local-path does not enforce the size and no retention is set, so it grows on that node's disk ([TODO](TODO.md#monitoring)) |
| Alloy | A DaemonSet on every node, the disposable one included, that ships **pod** logs to Loki. Host journals are not collected |
| Alertmanager | Disabled |

Dashboards are ConfigMaps in `infrastructure/monitoring/base/configs/`, loaded by the Grafana
sidecar. Without the tunnel:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
kubectl get secret -n monitoring grafana-admin-credentials \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

## Alerting reaches no one

Alertmanager is off, so nothing notifies anyone: a hung disk or a failed backup is seen only by
whoever looks ([TODO](TODO.md#monitoring)). The chart's default rules are loaded and evaluated.
There are no custom rules
([why](decisions.md#2026-10-11--custom-alert-rules-removed-until-they-have-a-purpose)).

A new `PrometheusRule` goes in `infrastructure/monitoring/base/configs/` with the label
`release: kube-prometheus-stack`. Check that Prometheus loaded it. The image has no `curl` or
`wget`, so go through the API server rather than `kubectl exec`:

```bash
kubectl get --raw /api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:9090/proxy/api/v1/rules \
  | jq -r '.data.groups[].name'
```

## Labels decide what gets picked up

Most "no data" problems here have been a missing label:

| Object | Must carry | Matched by |
|--------|------------|------------|
| PodMonitor | `app.kubernetes.io/component: monitoring` | `podMonitorSelector` in the HelmRelease |
| ServiceMonitor | `release: kube-prometheus-stack` | the chart's default `serviceMonitorSelector` |
| PrometheusRule | `release: kube-prometheus-stack` | the chart's default `ruleSelector` |
| Dashboard ConfigMap | `grafana_dashboard: "1"` | Grafana sidecar |
| Datasource ConfigMap | `grafana_datasource: "1"` | Grafana sidecar |

A PodMonitor can only select a port the container **declares**. The cloudflared chart serves
metrics on `:2000` without declaring it, so its HelmRelease patches the port in after rendering.

## Flux metrics

The controllers are scraped through the PodMonitor `flux-system` on port `http-prom`. The state of
Flux objects (`gotk_resource_info`, behind the Flux Cluster Stats dashboard) comes from
kube-state-metrics custom-resource state, configured twice: in the stack's own
kube-state-metrics and in a separate `flux-kube-state-metrics` Deployment
([TODO](TODO.md#monitoring)).

## Is an app still used?

Answer it with data before removing an app. Traefik counts requests per service and Prometheus
scrapes it. The dashboard **App Usage (Traefik)** (uid `app-usage`, default range 14 days) shows
requests per service, the idle ones, the request rate and the response bytes. From a shell:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 19090:9090
curl -s --get --data-urlencode 'query=sort_desc(sum by (service) (increase(traefik_service_requests_total[14d])))' \
  http://127.0.0.1:19090/api/v1/query | jq -r '.data.result[] | "\(.metric.service)\t\(.value[1]|tonumber|floor)"'
```

Service labels look like `apps-immich-server-2283@kubernetes`: namespace, service, port. The
Prometheus retention (`retention` in its HelmRelease) caps the window. A longer one needs a bigger
volume first, and since that volume is `local-path`, growing it means recreating it and losing
the history.

## Blind spots

Cross-check these before deleting anything:

- **Traffic that skips ingress.** qBittorrent seeds over the torrent protocol while its web UI
  sits at zero requests, so check `container_network_transmit_bytes_total`. A ClusterIP-only
  service never appears in Traefik's numbers: read its logs, e.g.
  `kubectl logs -n apps deploy/<app> | grep -v /health`.
- **Host processes.** restic, Tailscale, the NFS server, PostgreSQL and Hermes are visible only
  as machines through node-exporter. Their own health is unobserved.
