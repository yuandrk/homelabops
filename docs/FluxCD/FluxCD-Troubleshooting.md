# FluxCD Troubleshooting Guide

This document covers common FluxCD issues encountered during application management and their solutions.

## Common Issues and Solutions

### 1. Kustomization Failures with Empty YAML Files

#### Problem
```
kustomize build failed: accumulating resources: accumulation err='accumulating resources from './actualbudget': read /tmp/kustomization-xxx/apps/actualbudget: is a directory': couldn't make target for path '/tmp/kustomization-xxx/apps/actualbudget': kustomization.yaml is empty
```

#### Root Cause
- Commenting out kustomization.yaml content creates "empty" YAML files
- FluxCD/Kustomize cannot parse commented-out or empty YAML files
- Leads to persistent reconciliation failures

#### Solution
**Option 1: Remove directories entirely (Recommended)**
```bash
# Remove unwanted app directories completely
rm -rf apps/unwanted-app
rm -rf infrastructure/configs/unwanted-config

# Commit and push changes
git add -A
git commit -m "remove unused applications"
git push origin main
```

**Option 2: Create minimal valid kustomization.yaml**
```yaml
# If you need to keep directory structure but disable apps
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# No resources defined - valid but empty
```

#### Verification
```bash
# Check kustomization status
kubectl get kustomization -n flux-system

# Should show all as Ready: True
# NAME            AGE   READY   STATUS
# apps            1h    True    Applied revision: main@sha1:xxxxx
# infra-configs   1h    True    Applied revision: main@sha1:xxxxx
```

### 2. HelmRelease Timeout Issues

#### Problem
```
Helm install failed for release apps/open-webui with chart open-webui@4.1.0: context deadline exceeded
```

#### Root Cause
- Heavy applications (like open-webui with Ollama) take longer to start
- Default Helm timeout (5 minutes) insufficient for resource-constrained environments
- Particularly common on Raspberry Pi workers

#### Diagnosis
```bash
# Check if pods are actually running despite HelmRelease failure
kubectl get pods -n apps

# Check PVC binding status
kubectl get pvc -n apps

# Check detailed HelmRelease status
kubectl describe helmrelease <app-name> -n apps
```

#### Solutions

**Option 1: Increase timeout in HelmRelease**
```yaml
# apps/app-name/helm-release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: app-name
  namespace: apps
spec:
  timeout: 10m  # Increase from default 5m
  chart:
    spec:
      chart: app-name
      # ... rest of config
```

**Option 2: Add resource constraints for RPi**
```yaml
# In HelmRelease values
spec:
  values:
    resources:
      limits:
        memory: "1Gi"
        cpu: "500m"
    nodeSelector:
      "kubernetes.io/arch": "arm64"  # For RPi workers
```

**Option 3: Accept cosmetic failure if pods are healthy**
- If pods are running correctly, the HelmRelease failure is cosmetic
- Application will function normally despite the failed status

### 3. Repository Access Issues

#### Problem
```
failed to fetch Helm repository index: failed to fetch https://example.com/charts/index.yaml : 404 Not Found
```

#### Root Cause
- Incorrect or outdated Helm repository URLs
- Repository moved or deprecated

#### Solution
```bash
# Find correct repository URL (check official documentation)
# Update HelmRepository resource
kubectl edit helmrepository <repo-name> -n apps

# Or update the source file:
# apps/app-name/helm-repository.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: app-name
  namespace: apps
spec:
  url: https://correct-repo-url.com/charts  # Updated URL
```

### 4. Manual Cleanup of Stuck Resources

#### Removing Failed HelmReleases
```bash
# List HelmReleases
kubectl get helmreleases -A

# Delete specific HelmRelease
kubectl delete helmrelease <release-name> -n <namespace>

# Force delete if stuck with finalizers
kubectl patch helmrelease <release-name> -n <namespace> -p '{"metadata":{"finalizers":[]}}' --type=merge
```

#### Removing Orphaned Resources
```bash
# Check for orphaned PVCs
kubectl get pvc -A

# Check for orphaned ConfigMaps/Secrets
kubectl get configmap,secret -A | grep <app-name>

# Clean up manually if needed
kubectl delete pvc <pvc-name> -n <namespace>
```

## Application Management Workflow

### Adding New Applications

1. **Create app directory structure**
```bash
mkdir -p apps/new-app
```

2. **Create HelmRepository**
```yaml
# apps/new-app/helm-repository.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: new-app
  namespace: apps
spec:
  url: https://charts.example.com
  interval: 1h
```

3. **Create HelmRelease**
```yaml
# apps/new-app/helm-release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: new-app
  namespace: apps
spec:
  interval: 5m
  timeout: 10m  # Increase for heavy apps
  chart:
    spec:
      chart: new-app
      version: ">=1.0.0"
      sourceRef:
        kind: HelmRepository
        name: new-app
  values:
    # App-specific configuration
```

4. **Create Kustomization**
```yaml
# apps/new-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - helm-repository.yaml
  - helm-release.yaml
```

### Removing Applications

1. **Delete app directory entirely**
```bash
rm -rf apps/unwanted-app
rm -rf infrastructure/configs/unwanted-app
```

2. **Commit and push changes**
```bash
git add -A
git commit -m "remove unwanted application"
git push origin main
```

3. **Verify cleanup**
```bash
# FluxCD will automatically clean up resources due to prune: true
kubectl get helmreleases -A
kubectl get pods -A
```

### Troubleshooting Failed Applications

1. **Check FluxCD system health**
```bash
kubectl get pods -n flux-system
kubectl get kustomization -n flux-system
kubectl get gitrepository -n flux-system
```

2. **Check application-specific resources**
```bash
kubectl describe helmrelease <app> -n apps
kubectl get helmrepository -n apps
kubectl get pods -n apps
kubectl logs <pod-name> -n apps
```

3. **Force reconciliation**
```bash
# Force Git repository sync
kubectl annotate --overwrite gitrepository flux-system \
  -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"

# Force specific kustomization sync
kubectl annotate --overwrite kustomization apps \
  -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

## Monitoring and Alerts

### Key Metrics to Monitor
- Kustomization reconciliation status
- HelmRelease success/failure rates
- GitRepository sync status
- Resource utilization on RPi workers

### Useful Commands for Monitoring
```bash
# Overview of all FluxCD resources
kubectl get kustomization,helmrelease,gitrepository -A

# Check events for issues
kubectl get events -n flux-system --sort-by='.lastTimestamp'

# Monitor controller logs
kubectl logs -n flux-system deployment/kustomize-controller -f
kubectl logs -n flux-system deployment/helm-controller -f
kubectl logs -n flux-system deployment/source-controller -f
```

## Best Practices

### Resource Management
- Use resource limits for applications on RPi workers
- Increase timeouts for resource-intensive applications
- Consider node affinity for architecture-specific workloads

### GitOps Workflow
- Always test changes in development environment first
- Use meaningful commit messages for FluxCD tracking
- Remove unwanted resources completely rather than commenting out

### Troubleshooting Approach
1. Check FluxCD system health first
2. Verify Git repository connectivity
3. Check individual resource status
4. Review controller logs for specific errors
5. Force reconciliation when needed

### Configuration Management
- Keep kustomization.yaml files valid and minimal
- Use consistent naming conventions
- Document any custom configurations or workarounds

## Current Environment Status

### Working Configuration (August 2025)
- **FluxCD Version**: v2.6.0
- **Active Applications**: open-webui (LLM interface)
- **Removed Applications**: todoist, cert-manager, github, actualbudget, n8n, headlamp
- **Infrastructure**: K3s cluster with Raspberry Pi workers
- **Storage**: local-path provisioner for PVCs

### Known Issues
- **open-webui HelmRelease**: Shows as failed due to timeout, but application pods are healthy and running
- **RPi Resource Constraints**: Heavy applications may require increased timeouts and resource limits

This configuration provides a clean, functional GitOps setup with minimal resource usage suitable for homelab environments.
