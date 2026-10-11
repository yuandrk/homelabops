# Monitoring

What is collected, where to look, and what does not work yet.

## What runs

| Piece | Details |
|-------|---------|
| Prometheus (kube-prometheus-stack) | 15 days on a 10Gi `local-path` volume, amd64 nodes only. Scrapes node-exporter, kube-state-metrics, the Flux controllers and cloudflared (PodMonitors), and Traefik (`additionalScrapeConfigs`, job `traefik`) |
| Grafana | `grafana.yuandrk.net`, local admin from `grafana-admin-credentials`. Datasources: Prometheus, Loki, and `PostgreSQL-Homelab` (the PostgreSQL on k3s-worker3) |
| Loki | SingleBinary, filesystem storage on a 10Gi `local-path` volume on k3s-worker3. local-path does not enforce the size: in October 2026 Loki held 15 GB. Chunks and results caches are off |
| Alloy | A DaemonSet on every node (it tolerates the disposable taint) that ships **pod** logs to Loki. Host journals are not collected |
| Alertmanager | Disabled |

Dashboards are code: ConfigMaps in `infrastructure/monitoring/base/configs/` that the Grafana
sidecar loads. They are App Usage (Traefik, see [usage-metrics.md](usage-metrics.md)), Flux
Cluster Stats, Flux Control Plane, Nodes, Node Exporter and Node Exporter Full.

## Alerting reaches no one

- **Nothing sends notifications.** Alertmanager is `enabled: false`. When the USB-SSD of
  k3s-worker1 hung on 2026-10-05, nothing paged anyone, and a failed backup only shows up in
  `journalctl`.
- **The custom rules are not loaded.** `homelab-monitoring-rules` (18 alerts in `node.rules`,
  `kubernetes.rules` and `flux.rules`) is labelled `app`, `prometheus` and `role`, but not
  `release: kube-prometheus-stack`, and the live Prometheus selects rules by exactly that label
  (`ruleSelector`, checked 2026-10-11). After adding the label, confirm the groups appear:

  ```bash
  kubectl get --raw /api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:9090/proxy/api/v1/rules \
    | jq -r '.data.groups[].name' | grep -E 'node|kubernetes|flux'
  ```

  The Prometheus image has no `wget` or `curl`, so `kubectl exec` into it does not help.

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
metrics on `:2000` without declaring it, so its HelmRelease patches the port in after rendering
(`5da007a`).

## Flux metrics

The controllers are scraped through the PodMonitor `flux-system` on port `http-prom`. That
selector still lists the image-automation and image-reflector controllers, which were removed on
2026-08-01. This is harmless.

The state of Flux objects (`gotk_resource_info`, behind the Flux Cluster Stats dashboard) comes
from kube-state-metrics custom-resource state. It is configured **twice**: in the stack's own
kube-state-metrics, and in a separate `flux-kube-state-metrics` Deployment left over from
debugging that dashboard. One of them is redundant.

## Access

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
kubectl get secret -n monitoring grafana-admin-credentials \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

## Blind spots

- **Host processes.** restic, Tailscale, the NFS server, PostgreSQL and Hermes are visible only
  as machines through node-exporter. Their own health is unobserved.
- **Traffic that skips ingress.** See [usage-metrics.md](usage-metrics.md#blind-spots).

## Still missing

- Alert delivery: Alertmanager, or a Grafana contact point, plus the `release` label on the rules.
- Loki retention. Nothing in the HelmRelease sets it, and local-path does not cap the volume at
  10Gi, so logs pile up on k3s-worker3's root filesystem. If it fills, the kubelet starts
  evicting pods there, and the native PostgreSQL on that disk runs out of space as well.
- An alert on a failed backup ([backup.md](backup.md#still-missing)).
- Dropping one of the two Flux state collectors.
