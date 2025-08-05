# Monitoring Stack Overview

This document provides a comprehensive overview of the monitoring stack deployed in the K3s homelab cluster using FluxCD GitOps.

## Architecture Overview

The monitoring stack is based on the **kube-prometheus-stack** Helm chart and includes:

- **Prometheus**: Metrics collection and storage
- **Grafana**: Dashboards and visualization
- **Node Exporter**: System metrics from all K3s nodes
- **Kube State Metrics**: Kubernetes cluster state and Flux resources
- **PodMonitor**: Scrapes Flux controllers metrics
- **Custom Dashboards**: Pre-configured Flux monitoring dashboards

## Deployment Structure

### GitOps Layout
```
clusters/prod/monitoring/
├── controllers/
│   └── kube-prometheus-stack/
│       ├── namespace.yaml              # monitoring namespace
│       ├── repository.yaml             # Helm repository
│       ├── release.yaml                # HelmRelease configuration
│       ├── kube-state-metrics-config.yaml  # Flux metrics configuration
│       └── kustomization.yaml
└── configs/
    ├── podmonitor.yaml                 # Flux controllers scraping
    ├── dashboards/
    │   ├── control-plane.json          # Flux control plane dashboard
    │   └── cluster.json                # Cluster overview dashboard
    └── kustomization.yaml
```

### FluxCD Kustomizations
- **monitoring-controllers**: Deploys kube-prometheus-stack first
- **monitoring-configs**: Deploys PodMonitor and dashboards after CRDs are available
- **Dependency**: configs waits for controllers to be healthy

## Component Details

### Prometheus Configuration
- **Storage**: 10Gi PersistentVolume
- **Retention**: 15 days
- **Scraping**: Flux controllers via PodMonitor
- **Access**: Internal ClusterIP service on port 9090

### Grafana Configuration
- **Default Credentials**: admin / flux
- **Dashboards**: Auto-imported from ConfigMaps
- **Access**: Internal ClusterIP service on port 80
- **Storage**: Ephemeral (dashboards/config in ConfigMaps)

### Node Exporter
- **Deployment**: DaemonSet on all nodes
- **Metrics**: System-level metrics (CPU, memory, disk, network)
- **Port**: 9100 on each node

### Kube State Metrics
- **Purpose**: Kubernetes object state metrics
- **Flux Integration**: Custom resource state for Flux objects
- **Resources Monitored**: Kustomizations, HelmReleases, GitRepositories, etc.

### PodMonitor Configuration
```yaml
spec:
  namespaceSelector:
    matchNames:
      - flux-system
  selector:
    matchExpressions:
      - key: app
        operator: In
        values:
          - helm-controller
          - source-controller
          - kustomize-controller
          - notification-controller
          - image-automation-controller
          - image-reflector-controller
  podMetricsEndpoints:
    - port: http-prom
```

## Health Checks and Dependencies

### Monitoring Controllers Health Checks
- Deployment: `kube-prometheus-stack-operator`
- CRD: `podmonitors.monitoring.coreos.com`
- Timeout: 10 minutes
- Wait: true (blocks until healthy)

### Monitoring Configs Dependencies
- Depends on: `monitoring-controllers`
- Timeout: 5 minutes
- Resources: PodMonitor, Dashboard ConfigMaps

## Access Methods

### Port Forwarding (Local Access)
```bash
# Grafana (recommended)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Access: http://localhost:3000 (admin/flux)

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Access: http://localhost:9090
```

### Service Information
```bash
# Get service details
kubectl get svc -n monitoring

# Service endpoints
kubectl get endpoints -n monitoring
```

## Pre-configured Dashboards

### Flux Control Plane Dashboard
- **Purpose**: Monitor Flux controller health and performance
- **Metrics**: Controller CPU/memory, API requests, reconciliation stats
- **Panels**: Controllers status, work queue depth, resource usage
- **Source**: `dashboards/control-plane.json`

### Flux Cluster Dashboard  
- **Purpose**: Cluster-wide Flux resource monitoring
- **Metrics**: Git repositories, Kustomizations, Helm releases
- **Panels**: Sync status, resource counts, operation rates
- **Source**: `dashboards/cluster.json`

## Troubleshooting

### Check Monitoring Stack Status
```bash
# Kustomizations status
kubectl get kustomizations -n flux-system | grep monitoring

# All monitoring resources
kubectl get all -n monitoring

# Check operator logs
kubectl logs -n monitoring -l app.kubernetes.io/name=kube-prometheus-stack-operator

# Verify CRDs
kubectl get crd | grep monitoring.coreos.com
```

### Common Issues

#### PodMonitor CRD Not Found
- **Cause**: Prometheus Operator not deployed yet
- **Solution**: Wait for `monitoring-controllers` to be Ready
- **Check**: `kubectl get crd podmonitors.monitoring.coreos.com`

#### Grafana Not Accessible
- **Check**: `kubectl get pods -n monitoring | grep grafana`
- **Logs**: `kubectl logs -n monitoring -l app.kubernetes.io/name=grafana`
- **Service**: `kubectl get svc -n monitoring kube-prometheus-stack-grafana`

#### Missing Metrics
- **PodMonitor**: `kubectl get podmonitor -n monitoring -o yaml`
- **Targets**: Access Prometheus > Status > Targets
- **Flux Controllers**: Verify controllers have `http-prom` port exposed

### Force Reconciliation
```bash
# Trigger monitoring stack update
kubectl annotate kustomization monitoring-controllers -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
kubectl annotate kustomization monitoring-configs -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

## Monitoring Metrics

### Key Flux Metrics Available
- `gotk_resource_info`: Flux resource states
- `controller_runtime_reconcile_total`: Reconciliation counters
- `workqueue_*`: Controller work queue metrics  
- `rest_client_requests_total`: Kubernetes API requests
- `process_*`: Controller process metrics

### Prometheus Queries Examples
```promql
# Flux reconciliation rate
rate(controller_runtime_reconcile_total[5m])

# Failed reconciliations
controller_runtime_reconcile_total{result="error"}

# Controller CPU usage
rate(process_cpu_seconds_total{namespace="flux-system"}[5m])

# Flux resource readiness
gotk_resource_info{ready="True"}
```

This monitoring stack provides comprehensive observability for both the Kubernetes cluster and the FluxCD GitOps operations, enabling proactive monitoring and quick troubleshooting of deployment issues.
