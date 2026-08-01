# Usage Metrics — "is this app still worth hosting?"

Before removing an app, answer the question with data rather than memory. Traefik already exports
per-service request counters, so the whole audit is one query.

## Grafana

**Grafana → Dashboards → "App Usage (Traefik)"** (uid `app-usage`), default range **14 days**.

| Panel | Answers |
|-------|---------|
| Requests per service (selected range) | How much traffic each app actually served |
| Idle services (zero requests in range) | Direct removal candidates |
| Request rate per service | Whether traffic is real use or a flat line with stray spikes |
| Response bytes per service | Separates "opened the page once" from "streamed something" |

## CLI

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 19090:9090
```

```bash
curl -s --get --data-urlencode 'query=sort_desc(sum by (service) (increase(traefik_service_requests_total[14d])))' http://127.0.0.1:19090/api/v1/query | jq -r '.data.result[] | "\(.metric.service)\t\(.value[1]|tonumber|floor)"'
```

## Where the metrics come from

- **Traefik** exposes Prometheus metrics on entrypoint `metrics` (`:9100`). This is on by default in
  the k3s-bundled chart — `--metrics.prometheus=true` is already in the deployment args, no
  `HelmChartConfig` needed.
- Prometheus scrapes it via `additionalScrapeConfigs` (job `traefik`) in the kube-prometheus-stack
  HelmRelease, not via a PodMonitor.
- Service labels look like `apps-immich-server-2283@kubernetes` — namespace, service, port.

## Retention limits the window

`retention: 15d` in the kube-prometheus-stack HelmRelease, on a 10Gi PVC.

Measured: **~6 GB of TSDB blocks at 15d**, ≈0.4 GB/day at ~161k active series. A 14-day lookback
fits, but only just — there is little headroom left on the 10Gi volume.

To look back further, grow the PVC first:

| Retention | Approx. blocks | Suggested PVC |
|-----------|----------------|---------------|
| 15d (current) | ~6 GB | 10Gi (near full) |
| 30d | ~12 GB | 20Gi |
| 90d | ~36 GB | 50Gi |

The Prometheus PVC is `local-path` on k3s-worker3, so growing it means recreating the volume and
losing history — do it when you actually want the longer window, not preemptively.

## Blind spots

Traefik metrics only see **ingress** traffic. They will show zero for apps that are genuinely busy
by other means:

- **qBittorrent** — seeds over the torrent protocol; its web UI can sit at zero requests while the
  daemon moves gigabytes. Check `container_network_transmit_bytes_total` instead.
- **Anything with no Ingress** — a ClusterIP-only service never appears here at all. Check the pod
  logs for real requests, e.g. `kubectl logs -n apps deploy/<app> | grep -v /health`.
- **Hermes agent + gateway** — runs on k3s-master outside k3s entirely, so nothing in this cluster
  observes it. It is a monitoring blind spot; a blackbox probe or systemd exporter would close it.

Cross-check one of these before deleting anything.
