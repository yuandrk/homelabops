# Flux Cluster Stats Dashboard Troubleshooting Guide

## Problem Summary
The **Flux Cluster Stats** dashboard in Grafana is not displaying data, while the **Flux Control Plane** dashboard works correctly. This indicates that the `gotk_resource_info` metrics required by the cluster dashboard are not being exposed properly.

## Root Cause Analysis
The dashboard depends on two types of metrics:

1. **`gotk_reconcile_duration_seconds`** - Exposed by Flux controllers (✅ Working - Control Plane dashboard shows this)
2. **`gotk_resource_info`** - Exposed by kube-state-metrics with custom resource configuration (❌ Missing)

The second type of metrics requires kube-state-metrics to be configured with custom resource state definitions for Flux CRDs.

## Attempted Solutions

### 1. Initial Approach: Helm Chart Integration
**What was tried**: Added custom resource state configuration to the kube-prometheus-stack Helm release values.

**Location**: `clusters/prod/monitoring/controllers/kube-prometheus-stack/release.yaml`

**Issue**: The Helm chart may not be applying the custom resource configuration properly, or the configuration format might not be compatible with the chart version.

### 2. Alternative Approach: Dedicated Deployment  
**What was deployed**: Separate kube-state-metrics instance specifically for Flux custom resources.

**Location**: `clusters/prod/monitoring/configs/flux-kube-state-metrics.yaml`

**Components**:
- ServiceAccount with proper RBAC permissions
- ConfigMap with custom resource state definitions
- Deployment using `registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.0`
- Service and ServiceMonitor for Prometheus scraping

## Diagnostic Steps Required

### 1. Check FluxCD Reconciliation
```bash
# Check if monitoring configs are being reconciled
kubectl get kustomizations -n flux-system | grep monitoring

# Check for any reconciliation errors
kubectl describe kustomization monitoring-configs -n flux-system
```

### 2. Verify Pod Deployment
```bash
# Check if the dedicated flux-kube-state-metrics pod is running
kubectl get pods -n monitoring | grep flux-kube-state-metrics

# If pod exists, check its logs for any errors
kubectl logs -n monitoring deployment/flux-kube-state-metrics

# Check pod status and events
kubectl describe pod -n monitoring -l app.kubernetes.io/name=flux-kube-state-metrics
```

### 3. Test Metrics Endpoint
```bash
# Port-forward to the metrics service
kubectl port-forward -n monitoring svc/flux-kube-state-metrics 8080:8080 &

# Test if gotk_resource_info metrics are being exposed
curl http://localhost:8080/metrics | grep gotk_resource_info

# Count of expected metrics
curl http://localhost:8080/metrics | grep -c gotk_resource_info
```

### 4. Verify ServiceMonitor Integration
```bash
# Check if ServiceMonitor was created
kubectl get servicemonitor -n monitoring flux-kube-state-metrics -o yaml

# Verify labels match Prometheus selector
kubectl get prometheus -n monitoring kube-prometheus-stack-prometheus -o yaml | grep -A10 serviceMonitorSelector
```

### 5. Check Prometheus Targets
```bash
# Port-forward to Prometheus UI
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &

# Access Prometheus at http://localhost:9090
# Navigate to Status > Targets
# Look for "flux-kube-state-metrics" target and verify it's UP
```

### 6. Test Dashboard Queries in Prometheus
In Prometheus UI (http://localhost:9090), test these queries that the dashboard uses:

```promql
# Basic resource info query
gotk_resource_info

# Count of cluster reconcilers (should return a number > 0)
count(gotk_resource_info{customresource_kind=~"Kustomization|HelmRelease"})

# Count of sources (should return a number > 0)  
count(gotk_resource_info{customresource_kind=~"GitRepository|HelmRepository|Bucket|OCIRepository"})

# Check if customresource_kind labels are present
gotk_resource_info{customresource_kind="Kustomization"}
```

### 7. Verify Flux Resources Exist
```bash
# Check what Flux resources exist in the cluster
kubectl get kustomizations -A
kubectl get helmreleases -A  
kubectl get gitrepositories -A
kubectl get helmrepositories -A

# These should return actual resources that the metrics should reflect
```

## Expected Results

### Working State Indicators:
- ✅ `flux-kube-state-metrics` pod in Running state
- ✅ ServiceMonitor shows up in Prometheus targets as UP
- ✅ `curl http://localhost:8080/metrics | grep gotk_resource_info` returns multiple metrics
- ✅ Prometheus queries return non-zero values
- ✅ Dashboard shows actual numbers instead of "No data"

### Troubleshooting Tips:

1. **If pod is not running**: Check FluxCD reconciliation and pod events
2. **If pod runs but no metrics**: Check ConfigMap content and kube-state-metrics logs
3. **If metrics exist but not in Prometheus**: Check ServiceMonitor configuration and labels
4. **If in Prometheus but dashboard still empty**: Check dashboard datasource configuration

## Configuration Files to Review

1. **Helm Release**: `clusters/prod/monitoring/controllers/kube-prometheus-stack/release.yaml`
2. **Dedicated Metrics**: `clusters/prod/monitoring/configs/flux-kube-state-metrics.yaml`  
3. **Dashboard Config**: `clusters/prod/monitoring/configs/dashboards/cluster.json`
4. **Kustomization**: `clusters/prod/monitoring/configs/kustomization.yaml`

## Next Steps

1. Run the diagnostic commands above
2. Identify which step in the chain is failing
3. Check logs and events for specific error messages
4. If dedicated deployment isn't working, consider:
   - Different kube-state-metrics image version
   - Alternative configuration format
   - Manual ServiceMonitor debugging

The goal is to get `gotk_resource_info` metrics flowing from kube-state-metrics → Prometheus → Grafana dashboard.