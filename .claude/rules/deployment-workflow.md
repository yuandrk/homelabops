# GitOps Deployment Workflow

## Standard App Update Pattern

1. **Edit** manifest files in `apps/<app>/base/` or `infrastructure/<component>/base/`
2. **Commit** with a clear message describing the change
3. **Push** to `main` branch
4. **Reconcile** Flux source: `reconcile_flux_source(name="flux-system", namespace="flux-system", source_type="GitRepository")`
5. **Reconcile** kustomization: `reconcile_flux_kustomization(name="apps", namespace="flux-system")` (or `infrastructure`)
6. **Verify** with `get_kubernetes_resources` — check HelmRelease status, pod status, image tags

## Version Upgrade Pattern (e.g., Immich, ActualBudget)

1. Check current deployed version via `get_kubernetes_resources`
2. Research latest version available
3. Update image tags / chart version in the HelmRelease or Deployment manifest
4. For Helm charts with component-specific images: set tags per-component (not top-level)
5. Commit → Push → Reconcile → Verify (as above)
6. Monitor pod rollout: check for CrashLoopBackOff, ImagePullBackOff, ContainerCreating

## Troubleshooting

- **HelmRelease stuck**: Check `get_kubernetes_resources` for conditions/messages
- **Pods not updating**: Verify image tags in deployment spec match desired version
- **Slow rollout**: Large images (500MB+) can take 5-10 min to pull on first deploy
- **Self-healing**: Manually deleted resources are recreated by Flux on next reconciliation

## Key Namespaces

- `flux-system` — Flux controllers and GitRepository
- `apps` — User-facing applications
- `monitoring` — Prometheus, Grafana stack
- `kube-system` — Headlamp, Traefik, system components
