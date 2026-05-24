# Services & External Access

## Current Services

| Service | URL | Notes |
|---------|-----|-------|
| Immich | `photos.yuandrk.net` | Photo management, 500Gi NFS storage, v2.6.3 |
| ActualBudget | `budget.yuandrk.net` | Financial management, v26.3.0 |
| Headlamp | `headlamp.yuandrk.net` | K8s dashboard |
| Uptime Kuma | `uptime.yuandrk.net` | Service monitoring, 2Gi storage |
| pgAdmin4 | `pgadmin.yuandrk.net` | PostgreSQL admin |
| n8n | `n8n.yuandrk.net` | Workflow automation, 5Gi storage, PostgreSQL backend |
| Grafana | `grafana.yuandrk.net` | Dashboards (admin/flux) |

## Infrastructure Services

- **PostgreSQL**: Native on k3s-worker3
- **FluxCD**: GitOps continuous deployment
- **Traefik**: K3s ingress controller
- **Monitoring Stack**: Prometheus (10Gi PVC, 15d retention), Grafana, Node Exporter, Kube State Metrics
- **Loki**: Log aggregation (10Gi PVC), with chunks-cache and results-cache
- **Alloy**: Log collector DaemonSet (runs on all nodes)
- **NFS Provisioner**: External storage provisioner in `storage` namespace (used by Immich)
- **NVIDIA Device Plugin**: GPU support on k3s-worker3 (GeForce MX130) — currently no GPU consumers

## Cloudflare Tunnel Routing

cloudflared runs as a 2-replica HelmRelease in the `networking` namespace (see memory `cloudflared-in-cluster`). All tunnel ingresses target in-cluster Service DNS:

- `flux-webhook.yuandrk.net` → `http://webhook-receiver.flux-system.svc.cluster.local:80`
- Everything else → `http://traefik.kube-system.svc.cluster.local:80` (Traefik Service, port 80 → targetPort `web`/8000)
