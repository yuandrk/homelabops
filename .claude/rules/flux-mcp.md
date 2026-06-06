# FluxCD Operations (CLI)

**Use the `flux` and `kubectl` CLIs for all Flux operations.** This environment has no Flux
MCP server connected, so the `flux`/`kubectl` binaries (both installed) are the primary path.
If other rules or docs mention MCP tools like `reconcile_flux_source(...)`, treat them as the
equivalent CLI commands below.

## Query & Inspection

```bash
flux get all --all-namespaces            # everything Flux manages
flux get kustomizations -A               # Kustomization status
flux get helmreleases -A                 # HelmRelease status
flux get sources git -A                  # GitRepository status
flux logs --kind=Kustomization --name=apps -n flux-system   # controller logs for a resource
flux events --for Kustomization/apps -n flux-system          # recent events
flux tree kustomization apps -n flux-system                  # what a Kustomization renders
kubectl get pods -A --field-selector=status.phase!=Running   # unhealthy pods
kubectl describe <kind>/<name> -n <ns>                       # conditions/messages
```

## Reconciliation & Actions

```bash
# Standard "I just pushed to main" flow — pull source, then reconcile a Kustomization:
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization apps -n flux-system

# Reconcile a HelmRelease, optionally pulling its source first:
flux reconcile helmrelease <name> -n <ns> --with-source

# Suspend / resume (e.g. while debugging or doing manual surgery):
flux suspend kustomization <name> -n flux-system
flux resume  kustomization <name> -n flux-system
```

Prefer the `/reconcile [target]` slash command, which wraps the source + kustomization + verify flow.

## Current Flux Resources

- **Kustomizations**: `flux-system`, `apps`, `infrastructure`, `monitoring-controllers`, `monitoring-configs`, `secrets`, `storage`
- **HelmReleases**: `immich` (apps), `headlamp` (kube-system), `kube-prometheus-stack` (monitoring), `alloy` (monitoring), `loki` (monitoring), `nfs-subdir-external-provisioner` (storage)
- **GitRepository**: `flux-system` (watches `main` branch, 1m interval)

## Important

- This cluster is GitOps-managed and **self-heals**: manual `kubectl apply/delete/edit` is reverted
  on the next reconcile. Make changes by editing manifests → commit → push → reconcile.
  (A warn-only hook flags direct mutations — see `.claude/hooks/guard-mutations.sh`.)
- `flux reconcile` only re-runs reconciliation; it does not push your local commits. Commit and push
  to `main` first, otherwise the cluster reconciles the old state.
