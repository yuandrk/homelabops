# Secrets

Every credential lives in one 1Password vault, `homelab`. The cluster reads it through the
1Password Operator. Nothing secret is committed to git, encrypted or not.

## The chain

```
1Password vault "homelab"
   │  read through a 1Password service account
   ▼
Secret onepassword/onepassword-token      ← created by hand: the one secret Flux cannot create
   │
   ▼
1Password Operator                        ← HelmRelease 1password-operator in flux-system, runs in onepassword
   │  watches OnePasswordItem resources
   ▼
OnePasswordItem <name>                    ← namespace X, itemPath vaults/homelab/items/<item>
   │
   ▼
Secret <name> in namespace X              ← consumed by the workload
```

- The chart is 1Password's `connect`, but only the operator is installed (`connect.create:
  false`, `authMethod: service-account`). There is no Connect server.
- `onepassword-token` is the root of trust. It is not in git and cannot be: without it the
  operator reads nothing, so every other secret depends on it. Creating it is a bootstrap step,
  see [the rebuild runbook](runbooks/rebuild-k3s-master.md).
- Each field of a 1Password item becomes a key of the Secret, named after the field's label.

## Sync is slow on purpose: every 6 hours

`pollingInterval: 21600`. The Individual/Families plan allows 1,000 API requests per day per
account. The default 10-minute poll over ~10 items used about 3,000 and kept the account
permanently rate-limited (failed retries count too). Polling every 6 hours costs about 120 a day.

A new `OnePasswordItem` is synced as soon as Flux applies it. A **change** to an existing item
reaches the cluster on the next poll, up to six hours later. To pull it now, restart the
operator, which syncs everything on startup:

```bash
kubectl -n onepassword get deploy                    # find the operator Deployment
kubectl -n onepassword rollout restart deploy/<name>
```

`autoRestart: true` then restarts the Deployments that consume a changed Secret.

## What is in the vault

In-cluster, one `OnePasswordItem` per Secret:

| Secret (namespace) | 1Password item | Used by |
|--------------------|----------------|---------|
| `cloudflared-token` (networking) | `cloudflared-tunnel-token` | cloudflared HelmRelease, via `valuesFrom` |
| `grafana-admin-credentials` (monitoring) | same name | Grafana's local admin |
| `postgres-credentials` (monitoring) | same name | Grafana's PostgreSQL datasource |
| `headlamp-oidc` (kube-system) | `headlamp-oidc-okta` | Headlamp's Okta client |
| `headlamp-oidc` (flux-system) | `headlamp-oidc-authentik` | nothing: a leftover from the Authentik era |
| `headlamp-token` (kube-system) | same name | nothing in-cluster: it stores Headlamp's break-glass token, see [access.md](access.md) |
| `immich-credentials` (apps) | same name | Immich environment |
| `n8n-credentials` (apps) | same name | n8n database login and `N8N_ENCRYPTION_KEY` |
| `fleet-credentials` (apps) | same name | Fleet and its MySQL |
| `kite-credentials` (apps) | same name | Kite's Okta client and local admin |
| `hermes-sandbox-credentials` (hermes-sandbox) | same name | SearXNG secret key, browserless token |

The cloudflared item sits next to cloudflared in `infrastructure/networking/cloudflared/`. All
the others are in `clusters/prod/secrets/`.

Outside the cluster, the same vault holds, next to a few items unrelated to the homelab:

- `restic homelab`: the restic repository password. Without it neither backup can be read.
- `Backblaze B2 — restic homelab`: the bucket-scoped B2 key for the offsite backup
  ([backup.md](backup.md#offsite-copy-backblaze-b2)). A second item, `Backblaze B2 — restic repo`,
  also exists, and what it is for is not recorded.
- `Restic — Obsidian vault backup`: for the vault backup on k3s-master.
- `hermes-dashboard-oidc`: presumably the Hermes dashboard's Okta client.
- `k3s-sudo` and `legacy-key-yuandrk (from k3s-worker3)`: what they hold is not recorded.

No item holds Hermes' sandbox kubeconfig (`~/.hermes/kube-sandbox.conf`), whatever older notes
said. Regenerate it with `infrastructure/hermes-sandbox/make-kubeconfig.sh` instead.

Items whose consumer is gone are listed for deletion in [TODO](TODO.md#cleanup).

## Adding a secret

1. Create the item in vault `homelab`. Field labels become the Secret's keys.
2. Add `clusters/prod/secrets/<name>.yaml`:

   ```yaml
   apiVersion: onepassword.com/v1
   kind: OnePasswordItem
   metadata:
     name: <name>            # the Secret gets this name
     namespace: <namespace>
   spec:
     itemPath: "vaults/homelab/items/<item>"
   ```

3. List it in `clusters/prod/secrets/kustomization.yaml`.
4. Reference the Secret from the workload: `secretKeyRef`, `envFrom`, or `valuesFrom` on a
   HelmRelease.

The `secrets` Kustomization depends on `infrastructure`, which installs the operator and its
CRD. `apps` does not wait for `secrets`, so on a first deploy a pod can sit in
`CreateContainerConfigError` until its Secret appears. That is expected and clears itself.

## Removing a secret

- Delete the `OnePasswordItem` in the same commit as its consumer. If the namespace goes away in
  that commit, the item must go too. The `secrets` Kustomization applies into namespaces that
  other Kustomizations own, and a single item aimed at a missing namespace stops it reconciling
  **every** secret, not just that one (see [hermes-sandbox.md](hermes-sandbox.md#removing-it)).
- The vault item outlives the manifest. Delete it by hand in 1Password.

## History

Until 2026-05-17 secrets were SOPS/age-encrypted files in git. Commit `91b41dc` moved all eight
to 1Password and removed the decryption config from Flux. `.sops.yaml`, the `sops -d`
permission in `.claude/settings.json` and `.claude/hooks/guard-secrets.sh` are leftovers of
that setup.
