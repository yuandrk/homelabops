# Monitoring Troubleshooting Guide

**Quick reference for common monitoring issues in K3s homelab**

## 🚨 Quick Diagnostics

### One-liner Health Check
```bash
# Check all monitoring components status
KUBECONFIG=/path/to/kubeconfig kubectl get pods,servicemonitor,podmonitor,prometheusrules -n monitoring
```

## Common Issues & Solutions

### 1. **Flux Metrics Missing in Prometheus**

#### Symptoms:
- `gotk_*` metrics not appearing in Prometheus
- Flux dashboards show "No Data"
- ServiceMonitor/PodMonitor exist but no targets

#### Root Cause:
Label mismatch between monitors and Prometheus selectors

#### Solution:
```bash
# Check current labels on ServiceMonitor
kubectl get servicemonitor -n monitoring flux-kube-state-metrics -o jsonpath='{.metadata.labels}'

# Should include: "release":"kube-prometheus-stack"
# If missing, add to flux-kube-state-metrics.yaml:
labels:
  release: kube-prometheus-stack  # ← This is critical!
```

### 2. **Node Exporter Metrics Missing**

#### Symptoms:
- Node dashboards empty
- `node_*` metrics unavailable
- Node alerts not firing

#### Check:
```bash
# Verify node-exporter DaemonSet
kubectl get ds -n monitoring | grep node-exporter

# Check if running on all nodes
kubectl get pods -n monitoring | grep node-exporter
```

### 3. **Custom AlertRules Not Loading**

#### Symptoms:  
- Alerts missing in Grafana
- PrometheusRule exists but rules not active

#### Check:
```bash
# Verify PrometheusRule syntax
kubectl get prometheusrules -n monitoring homelab-monitoring-rules -o yaml

# Check Prometheus config reload
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0 | grep -i "reload"
```

### 4. **Grafana Dashboard Not Showing**

#### Symptoms:
- Custom dashboard missing from Grafana UI
- ConfigMap exists but not loaded

#### Solution:
```bash
# Check ConfigMap labels for Grafana discovery
kubectl get configmap -n monitoring node-exporter-dashboard -o yaml | grep labels -A 5

# Should have: grafana_dashboard: "1" 
# Check Grafana pod logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

## Prometheus Selector Issues

### The Most Common Problem ⚠️

**Issue**: Prometheus configured with restrictive selectors but monitors don't have matching labels.

**Check Selectors**:
```bash
kubectl get prometheus -n monitoring -o yaml | grep -A 5 "Monitor.*Selector"
```

**Common Selector Requirements**:
- ServiceMonitor needs: `release: kube-prometheus-stack`
- PodMonitor needs: `app.kubernetes.io/component: monitoring`

## FluxCD Integration Issues

### Kustomization Not Applying

```bash
# Check monitoring kustomization status
kubectl describe kustomization -n flux-system monitoring-configs

# Common issues:
# - Missing kustomization.yaml in subdirectories
# - Invalid YAML syntax
# - Resource conflicts
```

### Directory Structure Problems

**Correct Structure**:
```
clusters/prod/monitoring/
├── kustomization.yaml          # Must include "- configs"
└── configs/
    ├── kustomization.yaml      # Must list all resources
    ├── *.yaml                  # Actual resources
    └── dashboards/
        └── kustomization.yaml  # ConfigMapGenerator for dashboards
```

## Port and Service Issues

### Port-Forward Not Working

```bash
# Use internal ClusterIP instead of localhost
kubectl get svc -n monitoring kube-prometheus-stack-prometheus

# Test connectivity from inside cluster
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never -- \
  curl -s "http://CLUSTER-IP:9090/api/v1/targets"
```

## Recovery Procedures

### Complete Monitoring Reset

```bash
# 1. Delete monitoring namespace (⚠️ This removes all data!)
kubectl delete namespace monitoring

# 2. Wait for FluxCD to recreate
kubectl get kustomizations -n flux-system -w

# 3. Verify recreation
kubectl get all -n monitoring
```

### Prometheus Data Corruption

```bash
# Check Prometheus StatefulSet
kubectl get statefulset -n monitoring

# If data corrupted, delete PVC (⚠️ Loses all historical data!)
kubectl delete pvc -n monitoring prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0
```

## Useful Diagnostic Queries

### Check Prometheus Targets
```bash
# Via API (requires port-forward)
curl -s "http://localhost:9090/api/v1/targets" | \
  jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

### Test Specific Metrics
```promql
# In Grafana Explore or Prometheus UI:

# Check if Flux metrics exist
gotk_reconcile_duration_seconds_count

# Check node metrics  
up{job="node-exporter"}

# Check custom alerts
ALERTS{alertname=~"Node.*|Pod.*|Flux.*"}
```

## Prevention Tips

### 1. **Always Use Correct Labels**
- ServiceMonitor: `release: kube-prometheus-stack`
- PodMonitor: `app.kubernetes.io/component: monitoring`
- ConfigMap: `grafana_dashboard: "1"`

### 2. **Validate Before Commit**
```bash
# Test kustomization locally
kubectl kustomize clusters/prod/monitoring/configs/

# Check YAML syntax
yamllint clusters/prod/monitoring/configs/*.yaml
```

### 3. **Monitor the Monitoring**
- Set up alerts for Prometheus down
- Monitor FluxCD reconciliation status
- Regular health checks via Grafana

## Emergency Contacts

### When All Else Fails

1. **Check External Access**: https://grafana.yuandrk.net
2. **Node Direct Access**: SSH to k3s-master (10.10.0.1)
3. **Manual Prometheus**: `curl http://10.43.40.155:9090/api/v1/targets`

### Escalation Path

1. Check this guide ✅
2. Review [Enhanced Monitoring Setup](Enhanced-Monitoring-Setup.md)
3. Check [FluxCD Health Monitoring](FluxCD-Health-Monitoring.md)
4. Manual cluster inspection via SSH

---
**Last Updated**: August 2025  
**Tested On**: K3s v1.33.3+k3s1, kube-prometheus-stack v65.x