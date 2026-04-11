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
| Pi-hole | `pihole.yuandrk.net` | DNS + ad-blocking |
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

All services except Pi-hole route through Traefik ingress at `k3s-master:80`.

- `pihole.yuandrk.net` → `http://127.0.0.1:8081`
- `flux-webhook.yuandrk.net` → `http://k3s-worker1:30080`
- Everything else → `http://k3s-master:80` (Traefik)
