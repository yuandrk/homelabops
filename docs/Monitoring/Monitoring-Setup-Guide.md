# Monitoring Stack Setup Guide

This guide documents the setup and configuration of the monitoring stack in the K3s homelab cluster.

## Prerequisites

- ✅ K3s cluster operational (3 nodes)
- ✅ FluxCD v2 installed and configured
- ✅ GitOps repository structure in place
- ✅ Sufficient cluster resources (minimum 2GB RAM, 15GB storage)

## Setup History

### Implementation Date
**August 5, 2025** - Initial monitoring stack deployment

### Components Deployed
- **kube-prometheus-stack** Helm chart v45.5.5+
- **Prometheus** with 10Gi PVC storage, 15d retention
- **Grafana** with Flux-specific dashboards
- **Node Exporter** on all cluster nodes
- **Kube State Metrics** with Flux CRD support
- **PodMonitor** for Flux controller metrics

## File Structure Created

### Repository Layout
```
clusters/prod/
├── kustomization.yaml                          # Root kustomization (excludes monitoring from direct processing)
├── production/
│   ├── kustomization.yaml                      # Production resources kustomization
│   └── monitoring.yaml                         # Monitoring Kustomization definitions
├── infrastructure/
│   └── kustomization.yaml                      # Infrastructure resources kustomization
└── monitoring/
    ├── kustomization.yaml                      # Main monitoring kustomization
    ├── controllers/
    │   └── kube-prometheus-stack/
    │       ├── namespace.yaml                  # monitoring namespace
    │       ├── repository.yaml                 # prometheus-community Helm repo
    │       ├── release.yaml                    # kube-prometheus-stack HelmRelease
    │       ├── kube-state-metrics-config.yaml  # ConfigMap for Flux metrics
    │       └── kustomization.yaml
    └── configs/
        ├── podmonitor.yaml                     # Flux controllers PodMonitor
        ├── kustomization.yaml                  # Configs kustomization with ConfigMaps
        └── dashboards/
            ├── control-plane.json              # Flux control plane dashboard
            └── cluster.json                    # Cluster monitoring dashboard
```

## Key Configuration Details

### HelmRelease Configuration
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: kube-prometheus-stack
  namespace: monitoring
spec:
  chart:
    spec:
      chart: kube-prometheus-stack
      version: ">=45.5.5"
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
        namespace: monitoring
  values:
    nodeExporter:
      enabled: true
    kubeStateMetrics:
      enabled: true
    prometheus:
      prometheusSpec:
        retention: 15d
        storageSpec:
          volumeClaimTemplate:
            spec:
              accessModes: ["ReadWriteOnce"]
              resources:
                requests:
                  storage: 10Gi
        podMonitorSelector:
          matchLabels:
            app.kubernetes.io/component: monitoring
    grafana:
      defaultDashboardsEnabled: false
      adminPassword: flux
```

### FluxCD Kustomization Dependencies
```yaml
# monitoring-controllers (deployed first)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: monitoring-controllers
spec:
  wait: true
  timeout: 10m
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: kube-prometheus-stack-operator
    namespace: monitoring
  - apiVersion: apiextensions.k8s.io/v1
    kind: CustomResourceDefinition
    name: podmonitors.monitoring.coreos.com

---
# monitoring-configs (deployed after controllers are healthy)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: monitoring-configs
spec:
  dependsOn:
    - name: monitoring-controllers
  timeout: 5m
```

## Setup Process

### 1. Repository Structure Setup
```bash
# Created monitoring directory structure
mkdir -p clusters/prod/monitoring/{controllers/kube-prometheus-stack,configs/dashboards}

# Created root kustomization to control processing order
cat > clusters/prod/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- flux-system
- infrastructure  
- production
EOF
```

### 2. Helm Repository Configuration
```yaml
# clusters/prod/monitoring/controllers/kube-prometheus-stack/repository.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: monitoring
spec:
  interval: 1h
  url: https://prometheus-community.github.io/helm-charts
```

### 3. Kube State Metrics Configuration
Created ConfigMap with Flux CRD definitions for monitoring GitRepositories, Kustomizations, HelmReleases, and other Flux resources.

### 4. PodMonitor Setup
```yaml
# clusters/prod/monitoring/configs/podmonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: flux-system
  namespace: monitoring
  labels:
    app.kubernetes.io/component: monitoring
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

## Troubleshooting Issues Resolved

### Issue: PodMonitor CRD Not Found
**Problem**: `PodMonitor/monitoring/flux-system dry-run failed: no matches for kind "PodMonitor" in version "monitoring.coreos.com/v1"`

**Root Cause**: FluxCD was trying to apply PodMonitor resources before Prometheus Operator installed the CRDs.

**Solutions Applied**:
1. **Dependency Management**: Split into separate Kustomizations with `dependsOn`
2. **Health Checks**: Added explicit CRD health check for `podmonitors.monitoring.coreos.com`
3. **Wait Flag**: Added `wait: true` to ensure controllers fully ready
4. **Timeouts**: Extended timeout to 10m for Helm chart installation
5. **Structure Fix**: Created root kustomization to prevent direct resource processing

### Issue: Direct Resource Processing
**Problem**: Flux-system was processing monitoring resources directly instead of through Kustomizations.

**Solution**: Created `clusters/prod/kustomization.yaml` to control resource processing order and ensure Kustomization definitions are processed first.

## Deployment Timeline

### Initial Deployment (August 5, 2025)
- **21:06:33** - monitoring-controllers Kustomization created
- **21:06:42** - Prometheus Operator CRDs installed
- **21:06:44** - kube-prometheus-stack Helm release started
- **21:09:00** - All monitoring-controllers health checks passed
- **21:09:05** - monitoring-configs deployment started
- **21:09:42** - PodMonitor successfully created
- **21:09:42** - Dashboard ConfigMaps created

**Total Deployment Time**: ~3 minutes from start to fully operational

## Verification Commands

### Post-Setup Verification
```bash
# Check Kustomizations
kubectl get kustomizations -n flux-system | grep monitoring

# Verify all monitoring resources
kubectl get all -n monitoring

# Check CRDs installed
kubectl get crd | grep monitoring.coreos.com

# Verify PodMonitor created
kubectl get podmonitors -n monitoring

# Check dashboard ConfigMaps
kubectl get configmaps -n monitoring | grep dashboard

# Test Grafana access
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

### Expected Results
- ✅ `monitoring-controllers`: Ready/True
- ✅ `monitoring-configs`: Ready/True  
- ✅ PodMonitor: `flux-system` exists in monitoring namespace
- ✅ 10 monitoring CRDs installed
- ✅ 2 dashboard ConfigMaps created
- ✅ All monitoring pods Running

## Configuration Files

### Key Configuration Parameters
- **Chart Version**: `>=45.5.5` (prometheus-community/kube-prometheus-stack)
- **Storage**: 10Gi PersistentVolume for Prometheus
- **Retention**: 15 days
- **Grafana Password**: `flux` (default admin)
- **Node Exporter**: Enabled on all nodes
- **Alertmanager**: Disabled (not needed for this setup)

### Resource Requests/Limits
```yaml
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 200m
        memory: 200Mi
```

## Future Enhancements

### Planned Improvements
- [ ] Configure Cloudflare Tunnel for external Grafana access
- [ ] Add custom alerting rules for Flux failures
- [ ] Implement long-term metrics storage
- [ ] Add application-specific dashboards
- [ ] Configure notification channels

### Scaling Considerations
- Monitor storage usage (10Gi for 15d retention)
- Consider increasing retention for production workloads
- Add resource limits if cluster resources become constrained

This setup provides a solid foundation for monitoring the K3s cluster and FluxCD operations with minimal resource overhead and comprehensive observability.
