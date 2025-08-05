# Monitoring Stack Troubleshooting Guide

This guide provides solutions for common issues with the monitoring stack deployment and operation.

## Quick Diagnostics

### Essential Health Check Commands
```bash
# Set kubeconfig
export KUBECONFIG=/Users/yuandrk/Nextcloud/github/homelabops/terraform/kube/kubeconfig

# Check monitoring Kustomizations
kubectl get kustomizations -n flux-system | grep monitoring

# Check all monitoring resources
kubectl get all -n monitoring

# Check CRDs availability
kubectl get crd | grep monitoring.coreos.com

# Check PodMonitor
kubectl get podmonitors -n monitoring
```

## Common Issues and Solutions

### 1. PodMonitor CRD Not Found

**Symptoms:**
```
PodMonitor/monitoring/flux-system dry-run failed: no matches for kind "PodMonitor" in version "monitoring.coreos.com/v1"
```

**Root Cause:** Prometheus Operator hasn't installed the PodMonitor CRD yet.

**Diagnostic Commands:**
```bash
# Check if monitoring-controllers is ready
kubectl get kustomization monitoring-controllers -n flux-system

# Verify CRD installation
kubectl get crd podmonitors.monitoring.coreos.com

# Check operator deployment
kubectl get deployment kube-prometheus-stack-operator -n monitoring
```

**Solutions:**
1. **Wait for controllers**: Ensure `monitoring-controllers` shows `Ready: True`
2. **Check health checks**: Verify operator deployment and CRD health checks pass
3. **Force reconciliation**:
   ```bash
   kubectl annotate kustomization monitoring-controllers -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
   ```

### 2. Monitoring Controllers Stuck

**Symptoms:**
- `monitoring-controllers` shows `Unknown` or `False`
- Helm release installation timeout

**Diagnostic Commands:**
```bash
# Check Kustomization details
kubectl describe kustomization monitoring-controllers -n flux-system

# Check Helm release status
kubectl get helmreleases -n monitoring

# Check operator logs
kubectl logs -n monitoring -l app.kubernetes.io/name=kube-prometheus-stack-operator
```

**Solutions:**
1. **Resource constraints**: Check node resources
   ```bash
   kubectl top nodes
   kubectl describe nodes
   ```
2. **Storage issues**: Verify PVC creation
   ```bash
   kubectl get pvc -n monitoring
   kubectl describe pvc -n monitoring
   ```
3. **Network issues**: Check image pull status
   ```bash
   kubectl get events -n monitoring --sort-by='.lastTimestamp'
   ```

### 3. Monitoring Configs Failed

**Symptoms:**
- `monitoring-configs` shows dependency not ready
- PodMonitor not created

**Diagnostic Commands:**
```bash
# Check dependency status
kubectl describe kustomization monitoring-configs -n flux-system

# Verify PodMonitor CRD
kubectl get crd podmonitors.monitoring.coreos.com

# Check controller readiness
kubectl get deployment kube-prometheus-stack-operator -n monitoring
```

**Solutions:**
1. **Wait for dependencies**: Ensure `monitoring-controllers` is fully ready
2. **Manual dependency check**:
   ```bash
   # Verify operator is running
   kubectl get pods -n monitoring | grep operator
   
   # Verify CRD exists
   kubectl api-resources | grep podmonitor
   ```

### 4. Grafana Not Accessible

**Symptoms:**
- Grafana pod not running
- Cannot access Grafana dashboard

**Diagnostic Commands:**
```bash
# Check Grafana pod status
kubectl get pods -n monitoring | grep grafana

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Check service
kubectl get svc -n monitoring | grep grafana
```

**Solutions:**
1. **Pod issues**:
   ```bash
   # Describe pod for events
   kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana
   
   # Check resource limits
   kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o yaml | grep -A 10 resources
   ```
2. **Service issues**:
   ```bash
   # Port forward to test
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
   # Access: http://localhost:3000 (admin/flux)
   ```

### 5. Missing Prometheus Metrics

**Symptoms:**
- Prometheus targets showing down
- No Flux controller metrics

**Diagnostic Commands:**
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Access: http://localhost:9090/targets

# Check PodMonitor configuration
kubectl get podmonitor flux-system -n monitoring -o yaml

# Verify Flux controller ports
kubectl get pods -n flux-system -o yaml | grep -A 5 -B 5 http-prom
```

**Solutions:**
1. **PodMonitor selector issues**:
   ```bash
   # Check if PodMonitor matches pods
   kubectl get pods -n flux-system --show-labels
   
   # Verify PodMonitor selector
   kubectl get podmonitor flux-system -n monitoring -o jsonpath='{.spec.selector}'
   ```
2. **Service discovery issues**:
   ```bash
   # Check ServiceMonitor if needed
   kubectl get servicemonitors -n monitoring
   
   # Verify Prometheus configuration
   kubectl get prometheus -n monitoring -o yaml
   ```

### 6. Dashboard ConfigMaps Not Loading

**Symptoms:**
- Dashboards not appearing in Grafana
- ConfigMaps exist but not loaded

**Diagnostic Commands:**
```bash
# Check dashboard ConfigMaps
kubectl get configmaps -n monitoring | grep dashboard

# Verify ConfigMap labels
kubectl get configmap -n monitoring -l grafana_dashboard=1

# Check Grafana sidecar logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard
```

**Solutions:**
1. **Label issues**:
   ```bash
   # Verify ConfigMap has correct labels
   kubectl get configmap flux-control-plane-dashboard-* -n monitoring -o yaml | grep -A 5 labels
   ```
2. **Sidecar configuration**:
   ```bash
   # Check Grafana values for sidecar config
   kubectl get helmrelease kube-prometheus-stack -n monitoring -o yaml | grep -A 10 sidecar
   ```

## Performance Issues

### 7. High Memory Usage

**Symptoms:**
- Prometheus pod OOMKilled
- Node pressure warnings

**Diagnostic Commands:**
```bash
# Check resource usage
kubectl top pods -n monitoring

# Check memory limits
kubectl get pods -n monitoring -o yaml | grep -A 5 -B 5 memory
```

**Solutions:**
1. **Increase memory limits**:
   ```yaml
   # Update HelmRelease values
   prometheus:
     prometheusSpec:
       resources:
         requests:
           memory: 500Mi
         limits:
           memory: 1Gi
   ```
2. **Reduce retention**:
   ```yaml
   prometheus:
     prometheusSpec:
       retention: 7d  # Reduce from 15d
   ```

### 8. Storage Issues

**Symptoms:**
- PVC full warnings
- Prometheus failing to write

**Diagnostic Commands:**
```bash
# Check PVC usage
kubectl get pvc -n monitoring

# Check storage class
kubectl describe storageclass
```

**Solutions:**
1. **Increase storage**:
   ```yaml
   prometheus:
     prometheusSpec:
       storageSpec:
         volumeClaimTemplate:
           spec:
             resources:
               requests:
                 storage: 20Gi  # Increase from 10Gi
   ```

## Recovery Procedures

### Complete Stack Restart
```bash
# Delete monitoring Kustomizations (will trigger recreation)
kubectl delete kustomization monitoring-configs -n flux-system
kubectl delete kustomization monitoring-controllers -n flux-system

# Wait for FluxCD to recreate them
kubectl get kustomizations -n flux-system -w
```

### Force Clean Reinstall
```bash
# Delete namespace (WARNING: loses all data)
kubectl delete namespace monitoring

# Force reconciliation
kubectl annotate kustomization flux-system -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

## Monitoring the Monitoring Stack

### Health Check Script
```bash
#!/bin/bash
echo "🔍 Monitoring Stack Health Check"
echo "================================"

export KUBECONFIG=/Users/yuandrk/Nextcloud/github/homelabops/terraform/kube/kubeconfig

echo "📊 Monitoring Kustomizations:"
kubectl get kustomizations -n flux-system | grep monitoring | while read name age ready status; do
    if [ "$ready" = "True" ]; then
        echo "✅ $name"
    else
        echo "❌ $name - $status"
    fi
done

echo ""
echo "🔧 Monitoring Pods Status:"
kubectl get pods -n monitoring --no-headers | while read pod rest; do
    status=$(echo $rest | awk '{print $3}')
    if [ "$status" = "Running" ]; then
        echo "✅ $pod"
    else
        echo "❌ $pod - $status"
    fi
done

echo ""
echo "📈 Key Resources:"
echo "PodMonitors: $(kubectl get podmonitors -n monitoring 2>/dev/null | wc -l)"
echo "ServiceMonitors: $(kubectl get servicemonitors -n monitoring 2>/dev/null | wc -l)"
echo "Dashboard ConfigMaps: $(kubectl get configmaps -n monitoring -l grafana_dashboard=1 2>/dev/null | wc -l)"

echo ""
echo "💾 Storage Usage:"
kubectl get pvc -n monitoring --no-headers | while read name status volume capacity access mode age; do
    echo "📦 $name: $capacity ($status)"
done
```

## Prevention Best Practices

1. **Monitor resource usage regularly**
2. **Set up alerts for monitoring stack health**
3. **Keep regular backups of Grafana dashboards**
4. **Monitor storage usage and clean up old metrics**
5. **Test monitoring stack after cluster updates**

This troubleshooting guide should help resolve most common issues with the monitoring stack deployment and operation.
