# Monitoring Stack

## Components

- **Prometheus**: Metrics collection (10Gi PVC, 15d retention)
- **Grafana**: Dashboards at `grafana.yuandrk.net`. `admin/flux` no longer works — read the live
  credentials with:
  `kubectl get secret -n monitoring grafana-admin-credentials -o jsonpath='{.data.admin-password}' | base64 -d`
- **Node Exporter**: System metrics from all K3s nodes
- **Kube State Metrics**: Cluster state and Flux resources
- **PodMonitor**: Scrapes Flux controllers in `flux-system` namespace

## Quick Access

```bash
# Local Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Local Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

## Headlamp Dashboard

- URL: `headlamp.yuandrk.net`, login with Okta (OIDC through the k3s API server)
- Break-glass: a `headlamp-admin` ServiceAccount token, stored in 1Password (vault `homelab`, item
  `headlamp-token`) and synced to the `headlamp-token` Secret in `kube-system`. The token the old
  docs recorded was minted 2025-08-09 for one year, so unless it was rotated it expired 2026-08-09.
- Renew: `kubectl create token headlamp-admin -n kube-system --duration=8760h`, then paste it into
  the 1Password item (the cluster picks it up within 6h, see `docs/secrets.md`)
