# Secrets

Every credential lives in one 1Password vault, `homelab`. The cluster reads it through the
1Password Operator. Nothing secret is committed to git, encrypted or not
([why](decisions.md#2026-05-17--secrets-in-1password-instead-of-sops)).

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

- Only the operator is installed from 1Password's `connect` chart (`connect.create: false`,
  `authMethod: service-account`). There is no Connect server.
- `onepassword-token` is the root of trust: without it the operator reads nothing. It is not in
  git and cannot be, so creating it is a bootstrap step
  ([rebuild runbook](runbooks/rebuild-k3s-master.md#5-secrets-and-flux)).
- Each field of a 1Password item becomes a key of the Secret, named after the field's label.
- The items are in `clusters/prod/secrets/`, except cloudflared's, which sits next to its
  HelmRelease in `infrastructure/networking/cloudflared/`. Each one's `itemPath` names its vault
  item.

## Sync is slow on purpose: every 6 hours

`pollingInterval: 21600`. The Individual/Families plan allows 1,000 API requests a day, and the
default 10-minute poll over about ten items kept the account rate-limited. A new
`OnePasswordItem` syncs as soon as Flux applies it. A **change** to an existing item arrives on
the next poll, up to six hours later. To pull it now, restart the operator, which syncs
everything on startup; `autoRestart: true` then restarts the Deployments that use a changed
Secret:

```bash
kubectl -n onepassword get deploy                    # find the operator Deployment
kubectl -n onepassword rollout restart deploy/<name>
```

## Vault items used outside the cluster

Next to a few items unrelated to the homelab, the vault holds:

- `restic homelab`: the restic repository password. Without it neither backup can be read.
- `Backblaze B2 — restic homelab`: the bucket-scoped B2 key for the offsite backup, fields
  `keyID (B2_ACCOUNT_ID)`, `applicationKey` and `bucket`
  ([backup.md](backup.md#offsite-copy-backblaze-b2)).
- `Restic — Obsidian vault backup` and `Backblaze B2 — restic repo`: the Obsidian vault backup on
  k3s-master. The first is its restic password (`~/.restic-password`), the second its B2 key
  (`~/.restic-env`), limited to the bucket `obsidian-backup-yuandrk`.
- `healthchecks`: the healthchecks.io ping URLs, written by
  [runbooks/healthchecks.py](runbooks/healthchecks.py). Alertmanager reads its four through the
  Secret `healthchecks`; the four `restic-*` URLs were copied into `/etc/restic/healthchecks.env`
  on k3s-master, so a change to them has to be copied there again
  ([backup.md](backup.md#monitoring)).
- `ntfy`: the ntfy.sh topic, random, and Alertmanager's URL for it. Alertmanager reads `url`
  through the Secret `ntfy` and renders it as a template: it ends in
  `?tpl=alertmanager{{ if eq .Status "firing" }}&p=4{{ end }}`. The ntfy app on the phone
  subscribes to `topic` ([monitoring.md](monitoring.md#alerts)).
- `hermes-dashboard-oidc`, `k3s-sudo` and `legacy-key-yuandrk (from k3s-worker3)`: what they
  hold is not recorded ([TODO](TODO.md#unknowns)).

Hermes' sandbox kubeconfig is in no item: regenerate it
([hermes-sandbox.md](hermes-sandbox.md#access)). Items whose consumer is gone are listed for
deletion in [TODO](TODO.md#cleanup).

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
