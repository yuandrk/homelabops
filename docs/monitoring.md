# Monitoring

What is collected, where to look, and what does not work yet.

## What runs

| Piece | Details |
|-------|---------|
| Prometheus (kube-prometheus-stack) | On a 10Gi `local-path` volume, amd64 nodes only. Scrapes node-exporter, kube-state-metrics, the kubelets' cAdvisor, `flux-kube-state-metrics`, the Flux controllers and cloudflared (PodMonitors), and Traefik (`additionalScrapeConfigs`, job `traefik`), and keeps only [the listed metrics](#only-listed-metrics-are-kept) |
| Grafana | `grafana.yuandrk.net`, local admin from the `grafana-admin-credentials` Secret. Datasources: Prometheus, Loki, and `PostgreSQL-Homelab`, which still points at `k3s-worker1:5432`, where no PostgreSQL runs ([TODO](TODO.md#monitoring)) |
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

## Only listed metrics are kept

Prometheus keeps the metrics that something reads, and drops the rest as it scrapes
([why](decisions.md#2026-10-17--prometheus-keeps-only-the-metrics-something-reads)). A dashboard
or alert that needs another metric shows no data until the metric is added to its source's list,
and its history starts from that commit.

| Source | Read by | Its list |
|--------|---------|----------|
| node-exporter | the two node dashboards, and the record of a host that hung (disk I/O, pressure) | `prometheus-node-exporter` in the [kube-prometheus-stack HelmRelease](../infrastructure/monitoring/base/controllers/kube-prometheus-stack/release.yaml) |
| kube-state-metrics | Kite, the planned alerts | `kube-state-metrics`, same file |
| kubelet (cAdvisor) | Kite's pod and node charts, [traffic that skips ingress](#blind-spots) | `kubelet`, same file |
| Traefik | App Usage | the `traefik` job, same file |
| Flux controllers | Flux Cluster Stats | PodMonitor [`flux-system`](../infrastructure/monitoring/base/configs/podmonitor.yaml) |
| `flux-kube-state-metrics` | Flux Cluster Stats, the planned alerts | none needed: it serves only `gotk_resource_info` |
| cloudflared | the planned alerts | PodMonitor [`cloudflared`](../infrastructure/monitoring/base/configs/cloudflared-podmonitor.yaml) |

The API server, scheduler, controller-manager, kube-proxy, etcd and CoreDNS are not scraped, and
neither is the monitoring stack itself. The HelmRelease says why for the k3s components.

## Alerting reaches no one

Alertmanager is off, so nothing notifies anyone: a hung disk or a failed backup is seen only by
whoever looks ([TODO](TODO.md#monitoring)). There are no rules either. The chart's defaults are
off, because most of them read metrics that are no longer kept and three of their critical alerts
never stopped firing on k3s. The custom ones were removed
([why](decisions.md#2026-10-11--custom-alert-rules-removed-until-they-have-a-purpose)).

A new `PrometheusRule` goes in `infrastructure/monitoring/base/configs/` with the label
`release: kube-prometheus-stack`, and can only use kept metrics. Check that Prometheus loaded it.
The image has no `curl` or `wget`, so go through the API server rather than `kubectl exec`:

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

The state of every Flux object (`gotk_resource_info`: ready, suspended, revision) comes from
`flux-kube-state-metrics`, a kube-state-metrics Deployment that reads only the Flux kinds through
custom-resource state ([its config](../infrastructure/monitoring/base/configs/flux-kube-state-metrics.yaml)).
The stack's own kube-state-metrics does not collect it. The controllers themselves are scraped
through the PodMonitor `flux-system` on port `http-prom`, for their reconcile durations. Both feed
the Flux Cluster Stats dashboard.

## Is an app still used?

Answer it with data before removing an app. Traefik counts requests per service and Prometheus
scrapes it; k3s's bundled Traefik serves those metrics by default (port `metrics`), so no
`HelmChartConfig` is needed. The dashboard **App Usage (Traefik)** (uid `app-usage`, default range 14 days) shows
requests per service, the idle ones, the request rate and the response bytes. From a shell:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 19090:9090
curl -s --get --data-urlencode 'query=sort_desc(sum by (service) (increase(traefik_service_requests_total[14d])))' \
  http://127.0.0.1:19090/api/v1/query | jq -r '.data.result[] | "\(.metric.service)\t\(.value[1]|tonumber|floor)"'
```

Service labels look like `apps-immich-server-2283@kubernetes`: namespace, service, port. The
window is capped by the Prometheus retention, a year (`retention` in its HelmRelease).

## Blind spots

Cross-check these before deleting anything:

- **Traffic that skips ingress.** An app can be busy on another protocol, a torrent client
  seeding say, while its web UI sits at zero requests, so check
  `container_network_transmit_bytes_total`. A ClusterIP-only
  service never appears in Traefik's numbers: read its logs, e.g.
  `kubectl logs -n apps deploy/<app> | grep -v /health`.
- **Host processes.** restic, Tailscale, the NFS server, PostgreSQL and Hermes are visible only
  as machines through node-exporter. Their own health is unobserved.
