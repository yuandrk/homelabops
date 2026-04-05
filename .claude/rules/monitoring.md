# Monitoring Stack

## Components

- **Prometheus**: Metrics collection (10Gi PVC, 15d retention)
- **Grafana**: Dashboards at `grafana.yuandrk.net` (admin/flux)
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

- URL: `headlamp.yuandrk.net`
- Token: `sops -d infrastructure/configs/headlamp/token.enc.yaml | grep "token:" | awk '{print $2}'`
- Renew: `kubectl create token headlamp-admin -n kube-system --duration=8760h`
