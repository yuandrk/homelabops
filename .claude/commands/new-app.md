---
description: Scaffold a new app under apps/<name>/base and register it with Flux
argument-hint: "<name> [port] [storageGi]"
---

Scaffold a new application following the existing app pattern (see `apps/n8n/base/` and
`apps/whisper/base/`). Do NOT apply anything to the cluster — only create files and let
Flux deploy on the next reconcile.

Arguments:
- `$1` = app name (required, lowercase-kebab) — used as the resource name, label, and namespace stays `apps`.
- `$2` = container/service port (optional, default `8080`).
- `$3` = PVC size in Gi (optional; if omitted, skip the PVC and drop it from kustomization resources).

Steps:
1. If `apps/$1/` already exists, stop and tell me.
2. Create `apps/$1/base/` with these files, mirroring the n8n manifests exactly
   (namespace `apps`, `labels: { app: $1 }`, Traefik web entrypoint, host `$1.yuandrk.net`):
   - `deployment.yaml` — a single-replica Deployment. Leave `image:` as `REPLACE_ME:latest`
     with a `# TODO: set image` comment, container port `$2`, and mount the PVC at a sensible
     path only if a PVC is created.
   - `service.yaml` — ClusterIP, port `$2` → targetPort `$2`.
   - `ingress.yaml` — host `$1.yuandrk.net`, backend service `$1` port `$2`.
   - `pvc.yaml` — only if `$3` given: `$1-pvc`, `local-path`, ReadWriteOnce, `${3}Gi`.
   - `kustomization.yaml` — `resources:` listing the files created, plus `commonLabels: { app: $1 }`.
3. Register the app in `apps/kustomization.yaml` by adding `- $1/base` to the `resources:` list
   (keep alphabetical-ish ordering consistent with the file).
4. Validate locally (no cluster contact):
   ```bash
   kubectl kustomize apps/$1/base
   kubectl kustomize apps | kubectl apply --dry-run=client -f - >/dev/null && echo "apps kustomization OK"
   ```
5. Summarize what was created and remind me of the next steps: set the real image, then
   commit → push → `/reconcile apps`. If the app needs secrets, note that they go under
   `clusters/prod/secrets/` as SOPS-encrypted `*.enc`/`.yaml` (see `.sops.yaml`), not inline.
