# GitOps Deployment Workflow

## Standard App Update Pattern

1. **Edit** manifest files in `apps/<app>/base/` or `infrastructure/<component>/base/`
2. **Commit** with a clear message describing the change
3. **Push** to `main` branch
4. **Reconcile** Flux source: `flux reconcile source git flux-system -n flux-system`
5. **Reconcile** kustomization: `flux reconcile kustomization apps -n flux-system` (or `infrastructure`)
6. **Verify** with `flux get kustomization apps -n flux-system` and `kubectl get helmrelease,pods -n <ns>` — check status, pod state, image tags

> Shortcut: the `/reconcile [target]` slash command wraps steps 4–6.

## Version Upgrade Pattern (e.g., Immich, ActualBudget)

1. Check current deployed version via `kubectl get deploy,helmrelease -n <ns> -o wide`
2. Research latest version available
3. Update image tags / chart version in the HelmRelease or Deployment manifest
4. For Helm charts with component-specific images: set tags per-component (not top-level)
5. Commit → Push → Reconcile → Verify (as above)
6. Monitor pod rollout: check for CrashLoopBackOff, ImagePullBackOff, ContainerCreating

## Troubleshooting

- **HelmRelease stuck**: Check `kubectl describe helmrelease <name> -n <ns>` (or `flux get helmrelease -A`) for conditions/messages
- **Pods not updating**: Verify image tags in deployment spec match desired version
- **Slow rollout**: Large images (500MB+) can take 5-10 min to pull on first deploy
- **Self-healing**: Manually deleted resources are recreated by Flux on next reconciliation

## Key Namespaces

- `flux-system` — Flux controllers and GitRepository
- `apps` — User-facing applications
- `monitoring` — Prometheus, Grafana stack
- `kube-system` — Headlamp, Traefik, system components
