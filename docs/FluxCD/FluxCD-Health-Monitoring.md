# FluxCD Health Monitoring & System Status

This document provides comprehensive commands and procedures for monitoring FluxCD health, verifying synchronization, and troubleshooting GitOps deployments.

## Quick Health Check Commands

### Essential FluxCD Status Commands
```bash
# Set kubeconfig path (adjust path as needed)
export KUBECONFIG=/Users/yuandrk/Nextcloud/github/homelabops/terraform/kube/kubeconfig

# Quick overview of all FluxCD resources
kubectl get all -n flux-system

# Check FluxCD controller health
kubectl get pods -n flux-system

# Verify GitOps synchronization status
kubectl get kustomization -n flux-system
kubectl get gitrepository -n flux-system
```

## 1. FluxCD Installation Status

### Check FluxCD Pods
```bash
kubectl get pods -n flux-system
```

**Expected Output (✅ Healthy):**
```
NAME                                          READY   STATUS    RESTARTS   AGE
helm-controller-5c898f4887-h2h96              1/1     Running   0          34h
image-automation-controller-b8f997cc7-r45hg   1/1     Running   0          34h
image-reflector-controller-6f7b784b47-p4p5q   1/1     Running   1          34h
kustomize-controller-57c6bbfc4b-ptj8l         1/1     Running   1          34h
notification-controller-5f66f99d4d-zpvxg      1/1     Running   1          34h
source-controller-5f6985f6c4-wddfd            1/1     Running   0          34h
```

**Health Indicators:**
- ✅ All pods show `READY 1/1`
- ✅ All pods have `STATUS Running`
- ✅ Low restart counts (< 5 is normal)
- ❌ Any pod stuck in `CrashLoopBackOff`, `Error`, or `Pending`

### Check FluxCD Deployments
```bash
kubectl get deployments -n flux-system
```

**Expected Output (✅ Healthy):**
```
NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
helm-controller               1/1     1            1           34h
image-automation-controller   1/1     1            1           34h
image-reflector-controller    1/1     1            1           34h
kustomize-controller          1/1     1            1           34h
notification-controller       1/1     1            1           34h
source-controller             1/1     1            1           34h
```

**Health Indicators:**
- ✅ All controllers show `READY 1/1`
- ✅ `UP-TO-DATE` matches `AVAILABLE`
- ❌ Any controller showing `0/1` ready

## 2. Git Repository Synchronization Status

### Check Git Repository Source
```bash
kubectl get gitrepository -n flux-system
```

**Expected Output (✅ Healthy):**
```
NAME          URL                                           AGE   READY   STATUS
flux-system   ssh://git@github.com/yuandrk/homelabops.git   34h   True    stored artifact for revision 'main@sha1:8853290...'
```

**Health Indicators:**
- ✅ `READY` shows `True`
- ✅ `STATUS` shows `stored artifact for revision 'main@sha1:...'`
- ❌ `READY` shows `False` or `Unknown`
- ❌ `STATUS` shows error messages

### Detailed Git Repository Status
```bash
kubectl describe gitrepository flux-system -n flux-system
```

**Key sections to check:**
```yaml
Status:
  Conditions:
    Status: True
    Type: Ready
    Message: stored artifact for revision 'main@sha1:...'
  
  Artifact:
    Revision: main@sha1:8853290963e2c356b9fa1362bf303aaa9a52a676
    Last Update Time: 2025-08-03T21:37:55Z
```

**Health Indicators:**
- ✅ `Conditions.Status: True` with `Type: Ready`
- ✅ Recent `Last Update Time` (within last few minutes)
- ✅ `Revision` matches latest Git commit
- ❌ Any condition with `Status: False`

## 3. Kustomization Sync Status

### Check All Kustomizations
```bash
kubectl get kustomization -n flux-system
```

**Expected Output (✅ Healthy):**
```
NAME            AGE   READY   STATUS
apps            34h   True    Applied revision: main@sha1:8853290963e2c356b9fa1362bf303aaa9a52a676
flux-system     34h   True    Applied revision: main@sha1:8853290963e2c356b9fa1362bf303aaa9a52a676
infra-configs   34h   True    Applied revision: main@sha1:8853290963e2c356b9fa1362bf303aaa9a52a676
```

**Health Indicators:**
- ✅ All kustomizations show `READY True`
- ✅ All show `Applied revision: main@sha1:...` with recent commit
- ✅ Revision hashes match across all kustomizations
- ❌ Any kustomization with `READY False`
- ❌ Different revision hashes (sync lag)

### Detailed Kustomization Status
```bash
# Check specific kustomization
kubectl describe kustomization apps -n flux-system
kubectl describe kustomization infra-configs -n flux-system
```

## 4. Application Health Status

### Check HelmReleases
```bash
kubectl get helmrelease -A
```

**Expected Output (✅ Healthy):**
```
NAMESPACE   NAME         AGE   READY   STATUS
apps        open-webui   34h   True    Helm upgrade succeeded for release apps/open-webui.v3 with chart open-webui@7.0.1
```

**Health Indicators:**
- ✅ `READY True` with successful status message
- ✅ Recent chart version deployment
- ❌ `READY False` or error in status

### Check Application Pods
```bash
kubectl get pods -n apps
```

**Expected Output (✅ Healthy):**
```
NAME                                    READY   STATUS    RESTARTS   AGE
open-webui-0                            1/1     Running   0          33h
open-webui-ollama-5b5cf776c7-rx5pj      1/1     Running   0          33h
open-webui-pipelines-5b6f5f9fc5-p29g9   1/1     Running   0          33h
```

### Check Ingress Status
```bash
kubectl get ingress -n apps
```

**Expected Output (✅ Healthy):**
```
NAME              CLASS     HOSTS              ADDRESS                                    PORTS     AGE
openweb-ingress   traefik   chat.yuandrk.net   192.168.1.137,192.168.1.223,192.168.1.70   80, 443   32h
```

## 5. FluxCD Logs and Debugging

### Controller Logs
```bash
# Source controller (Git sync)
kubectl logs -n flux-system -l app=source-controller --tail=50

# Kustomize controller (resource application)
kubectl logs -n flux-system -l app=kustomize-controller --tail=50

# Helm controller (Helm releases)
kubectl logs -n flux-system -l app=helm-controller --tail=50

# Follow logs in real-time
kubectl logs -n flux-system -l app=source-controller -f
```

### Check Events
```bash
# FluxCD system events
kubectl get events -n flux-system --sort-by='.lastTimestamp'

# Application namespace events
kubectl get events -n apps --sort-by='.lastTimestamp'

# All events across cluster
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
```

## 6. Force Reconciliation

### Manual Sync Triggers
```bash
# Force Git repository sync
kubectl annotate --overwrite gitrepository flux-system -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"

# Force kustomization sync
kubectl annotate --overwrite kustomization apps -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
kubectl annotate --overwrite kustomization infra-configs -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"

# Force Helm release sync
kubectl annotate --overwrite helmrelease open-webui -n apps reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

## 7. System Health Dashboard Script

Create a monitoring script for regular health checks:

```bash
#!/bin/bash
# FluxCD Health Check Script

echo "🔍 FluxCD Health Check - $(date)"
echo "================================"

# Set kubeconfig
export KUBECONFIG=/path/to/your/kubeconfig

echo ""
echo "📊 FluxCD Controllers Status:"
kubectl get pods -n flux-system --no-headers | while read pod rest; do
    status=$(echo $rest | awk '{print $3}')
    if [ "$status" = "Running" ]; then
        echo "✅ $pod"
    else
        echo "❌ $pod - $status"
    fi
done

echo ""
echo "🔄 Git Repository Sync:"
repo_status=$(kubectl get gitrepository flux-system -n flux-system --no-headers | awk '{print $4}')
if [ "$repo_status" = "True" ]; then
    echo "✅ Git repository synced"
    kubectl get gitrepository flux-system -n flux-system --no-headers | awk '{print "   Latest:", $5, $6, $7, $8}'
else
    echo "❌ Git repository sync failed"
fi

echo ""
echo "📦 Kustomizations Status:"
kubectl get kustomization -n flux-system --no-headers | while read name age ready status; do
    if [ "$ready" = "True" ]; then
        echo "✅ $name"
    else
        echo "❌ $name - $status"
    fi
done

echo ""
echo "🚀 Applications Status:"
kubectl get helmrelease -A --no-headers | while read ns name age ready status; do
    if [ "$ready" = "True" ]; then
        echo "✅ $ns/$name"
    else
        echo "❌ $ns/$name - $status"
    fi
done

echo ""
echo "🌐 External Services:"
curl -s -o /dev/null -w "chat.yuandrk.net: %{http_code}\n" https://chat.yuandrk.net
curl -s -o /dev/null -w "pihole.yuandrk.net: %{http_code}\n" https://pihole.yuandrk.net

echo ""
echo "✅ Health check complete!"
```

## 8. Common Issues and Solutions

### Issue: Git Repository Sync Failed
**Symptoms:**
- `gitrepository` shows `READY False`
- Error messages about authentication or network

**Solutions:**
```bash
# Check SSH key secret
kubectl get secret flux-system -n flux-system -o yaml

# Verify repository URL and branch
kubectl get gitrepository flux-system -n flux-system -o yaml

# Check source controller logs
kubectl logs -n flux-system -l app=source-controller --tail=100
```

### Issue: Kustomization Failed
**Symptoms:**
- `kustomization` shows `READY False`
- Applications not deploying

**Solutions:**
```bash
# Check kustomization details
kubectl describe kustomization apps -n flux-system

# Verify file structure in repository
# Check for syntax errors in YAML files

# Check kustomize controller logs
kubectl logs -n flux-system -l app=kustomize-controller --tail=100
```

### Issue: Helm Release Failed
**Symptoms:**
- `helmrelease` shows `READY False`
- Pods not starting or in error state

**Solutions:**
```bash
# Check Helm release details
kubectl describe helmrelease open-webui -n apps

# Check Helm controller logs
kubectl logs -n flux-system -l app=helm-controller --tail=100

# Manual Helm troubleshooting
helm list -A
helm status open-webui -n apps
```

## 9. Performance Monitoring

### Resource Usage
```bash
# FluxCD controller resource usage
kubectl top pods -n flux-system

# Memory and CPU usage over time
kubectl get pods -n flux-system -o custom-columns=NAME:.metadata.name,MEMORY:.status.containerStatuses[0].resources.requests.memory,CPU:.status.containerStatuses[0].resources.requests.cpu
```

### Sync Performance
```bash
# Check sync frequency and performance
kubectl get gitrepository flux-system -n flux-system -o jsonpath='{.spec.interval}'

# Recent reconciliation events
kubectl get events -n flux-system --field-selector reason=GitOperationSucceeded --sort-by='.lastTimestamp' | tail -10
```

## 10. Backup and Recovery

### Export FluxCD Configuration
```bash
# Export all FluxCD resources
kubectl get gitrepository,kustomization,helmrelease -A -o yaml > fluxcd-backup.yaml

# Export secrets (be careful with sensitive data)
kubectl get secret flux-system -n flux-system -o yaml > flux-secrets-backup.yaml
```

### Recovery Procedures
```bash
# Reinstall FluxCD (if needed)
flux uninstall --namespace=flux-system
# Then redeploy via Terraform

# Restore from backup
kubectl apply -f fluxcd-backup.yaml
```

This comprehensive monitoring guide ensures you can maintain healthy GitOps operations and quickly identify and resolve any issues with your FluxCD deployment.
