# homelabops

A three-node k3s homelab: Flux applies the cluster from `main`, GitHub Actions applies the
Cloudflare edge with Terraform, and a few services run on the hosts on purpose. This page is how
to work here, for agents and people. The repository is public.

## Layout

```
clusters/prod/           Flux entry point; secrets/ holds most OnePasswordItems
apps/<app>/base/         user-facing apps
infrastructure/          operator, monitoring, cloudflared, Hermes sandbox and dashboard
terraform/live/homelab/  cloudflare/ is applied by CI; the other stacks were applied once by hand
docs/                    the docs below, procedures in docs/runbooks/
.claude/                 commands (/reconcile, /new-app, /upgrade-app, /cluster-status), agents, hooks
```

## Rules

1. **Change the cluster through git**: edit, commit, land it on `main` (a PR shows Terraform's
   plan first), then `/reconcile`. Flux polls `main` every minute and reverts hand edits.
2. **Terraform runs only in CI**: the PR shows the plan, the merge applies it, and there is no
   approval gate. Never apply the cloudflare stack locally.
3. **Secrets live in 1Password** (vault `homelab`) and reach the cluster as `OnePasswordItem`s.
   Never commit Secret data, `terraform.tfvars` or state.
4. **The hostname decides how an app is exposed**: `<app>.yuandrk.net` is public and needs an
   entry in `local.tunnel_services`; `<app>.home.yuandrk.net` is tailnet-only and needs nothing
   else. That is naming, not access control: the home LAN reaches any app with a `Host` header,
   so every app keeps its own login. No NodePorts for LAN access, except Immich's 30283 for its
   mobile app.
5. **Data that matters lives under `/srv/data` on k3s-master**, the only node that is backed
   up, with its pod pinned there. k3s-worker1 is disposable: nothing important goes there. A
   `local-path` volume pins its pod to its node.
6. **The repository is public**: no secret values, no personal details (email addresses, Okta
   client IDs, the tailnet name), and never an inventory report.

## Where to look

| When you… | Read |
|-----------|------|
| need the big picture: nodes, pinning, how requests, changes and data flow | [architecture](docs/architecture.md) |
| wonder why something is the way it is | [decisions](docs/decisions.md) |
| add, upgrade or remove an app, or debug Flux | [gitops](docs/gitops.md) |
| touch DNS, the tunnel, Tailscale or a port | [network](docs/network-architecture.md) |
| deal with a login, Okta or break-glass | [access](docs/access.md) |
| add or change a secret | [secrets](docs/secrets.md) |
| change `terraform/` or its workflows | [terraform](docs/terraform-guide.md) |
| review a Renovate PR | [renovate](docs/renovate-config.md) |
| work on metrics, logs, alerts or app usage | [monitoring](docs/monitoring.md) |
| touch data, backups or a restore | [backup](docs/backup.md) |
| change a host or an external account | [off-git](docs/off-git.md) |
| work on Hermes | [hermes-dashboard](docs/hermes-dashboard.md), [hermes-sandbox](docs/hermes-sandbox.md) |
| upgrade k3s, rebuild k3s-master, check the docs against the machines | [runbooks](docs/runbooks/) |
| look for open work or unknowns | [TODO](docs/TODO.md) |

## Traps

- An empty or commented-out `kustomization.yaml` breaks its whole Kustomization. Two
  Kustomizations apply the monitoring stack ([gitops](docs/gitops.md#traps-in-this-repo)).
- Prometheus only picks up labelled objects
  ([monitoring](docs/monitoring.md#labels-decide-what-gets-picked-up)) and keeps only allowlisted
  metrics ([monitoring](docs/monitoring.md#only-listed-metrics-are-kept)). An alert without an
  `area` label reaches no one ([monitoring](docs/monitoring.md#alerts)).
- A 1Password change takes up to 6 hours to arrive; restart the operator to sync now. A first
  deploy can wait in `CreateContainerConfigError` for its Secret. Remove a `OnePasswordItem` in
  the same commit as the app it serves: one that outlives its namespace stops every secret
  syncing ([secrets](docs/secrets.md#removing-a-secret)).
- Renovate removes `{{ }}` before reading a manifest and silently skips one that is then invalid
  YAML, such as the Alertmanager templates without `|2-` ([renovate](docs/renovate-config.md#traps)).
- k3s-master's `192.168.1.223` (k3s config, Hermes EndpointSlice) and `100.96.117.64`
  (`internal_ingress_ip`) are hardcoded.
- On k3s-master, non-interactive `kubectl` needs `KUBECONFIG=~/.kube/config`
  ([access](docs/access.md#login-surfaces)).

## Writing docs

- Write intent, reasons, constraints and state outside git, not what `kubectl`, `flux` or `git`
  answer (versions, sizes, "runs on X"). Runbooks and decisions may carry values and dates.
  Evidence goes in commit messages, reasons in [decisions](docs/decisions.md), never in agent
  memory.
- One fact, one place: link to the owner, or to a manifest comment that already explains it.
  `README.md` is the showcase; it owns only the Services table.
- Open work and unknowns live only in [TODO](docs/TODO.md); a doc states a gap in one line and
  links there. No generic commands, emoji headings or status checkmarks.

| When you change… | Also update |
|------------------|-------------|
| an app or its hostname | Services in `README.md`; `local.tunnel_services` if public; on removal, the [removal log](docs/decisions.md#removed-apps) and [checklist](docs/gitops.md#removing-an-app) |
| a host or an external console | [off-git](docs/off-git.md) |
| logins or break-glass | [access](docs/access.md) |
| where data lives or its backup | [backup](docs/backup.md), and the data section of [architecture](docs/architecture.md) |
| a vault item used outside the cluster | [secrets](docs/secrets.md) |
| nodes, principles or a known gap | [architecture](docs/architecture.md) or [TODO](docs/TODO.md), and the summary in `README.md` |
| a choice a future reader would question | [decisions](docs/decisions.md) |
