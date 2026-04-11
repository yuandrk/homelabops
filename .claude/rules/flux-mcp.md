# FluxCD MCP Tools Reference

**ALWAYS prefer MCP tools over kubectl commands** for Flux operations.

## Query & Inspection

- `get_flux_instance` - Flux installation status and controller health
- `get_kubernetes_resources` - Any K8s resources (Kustomizations, HelmReleases, GitRepositories, etc.)
- `get_kubernetes_api_versions` - Available CRDs and apiVersions
- `get_kubernetes_logs` - Pod logs
- `get_kubernetes_metrics` - Pod resource usage
- `search_flux_docs` - Search official Flux documentation

## Reconciliation & Actions

- `reconcile_flux_kustomization` - Force reconcile a Kustomization
- `reconcile_flux_helmrelease` - Force reconcile a HelmRelease (with optional source reconciliation)
- `reconcile_flux_source` - Force reconcile a GitRepository/HelmRepository/OCIRepository/Bucket/HelmChart
- `suspend_flux_reconciliation` - Suspend reconciliation for a Flux resource
- `resume_flux_reconciliation` - Resume reconciliation for a suspended resource

## Resource Management

- `apply_kubernetes_manifest` - Apply YAML manifests to the cluster
- `delete_kubernetes_resource` - Delete a Kubernetes resource

## Current Flux Resources

- **Kustomizations**: `flux-system`, `apps`, `infrastructure`, `monitoring-controllers`, `monitoring-configs`, `secrets`, `storage`
- **HelmReleases**: `immich` (apps), `headlamp` (kube-system), `kube-prometheus-stack` (monitoring), `alloy` (monitoring), `loki` (monitoring), `nfs-subdir-external-provisioner` (storage)
- **GitRepository**: `flux-system` (watches main branch, 1m interval)

## Kubectl Fallback (only when MCP is unavailable)

```bash
kubectl get kustomizations -n flux-system
kubectl get helmreleases -A
flux reconcile kustomization apps
flux reconcile helmrelease -n monitoring kube-prometheus-stack --with-source
```
