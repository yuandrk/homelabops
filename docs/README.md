# Docs

These docs hold what the repository and the cluster cannot tell you themselves: intent, reasons,
constraints, failure modes, and the state that lives outside git. Anything you can ask
`kubectl`, `flux` or `git` for (versions, counts, what is running where right now) is
deliberately left out, because a copy of it here would go stale.

## Start here

| Doc | Read it for |
|-----|-------------|
| [architecture.md](architecture.md) | The principles, the nodes, what is pinned where and why, how requests, changes and data flow |
| [decisions.md](decisions.md) | Why things are the way they are, and which apps were removed |

## How it works

| Doc | Covers |
|-----|--------|
| [network-architecture.md](network-architecture.md) | LAN, Tailscale, split-horizon DNS without a DNS server, the Cloudflare Tunnel |
| [access.md](access.md) | Okta SSO, who can log in where, break-glass when Okta is down |
| [secrets.md](secrets.md) | 1Password to the operator to Secrets, the bootstrap token, the 6-hour sync |
| [gitops.md](gitops.md) | Flux Kustomizations, adding, upgrading and removing apps, traps, Claude Code tooling |
| [terraform-guide.md](terraform-guide.md) | The Cloudflare stack, CI with AWS OIDC, the one-time AWS and Flux stacks |
| [renovate-config.md](renovate-config.md) | What gets update PRs, and what silently does not |
| [monitoring.md](monitoring.md) | Prometheus, Loki, Grafana, and why no alert reaches anyone yet |
| [usage-metrics.md](usage-metrics.md) | Whether an app is still worth hosting, answered from Traefik metrics |
| [backup.md](backup.md) | Where the data lives and its three copies: NVMe, worker1, Backblaze B2 |

## Components with their own story

| Doc | Covers |
|-----|--------|
| [hermes-sandbox.md](hermes-sandbox.md) | The AI agent's scoped namespace: PodSecurity, default-deny network, quota |
| [hermes-dashboard.md](hermes-dashboard.md) | A host process behind Traefik and Okta, and its two-part HTTPS fix |

## When things break

| Doc | Covers |
|-----|--------|
| [off-git.md](off-git.md) | Everything Flux cannot rebuild: host config, external accounts, open questions |
| [runbooks/rebuild-k3s-master.md](runbooks/rebuild-k3s-master.md) | Bringing back the node that holds everything (draft) |
| [runbooks/upgrade-k3s.md](runbooks/upgrade-k3s.md) | Upgrading k3s without losing the flags that live only in the unit file |
| [runbooks/inventory.md](runbooks/inventory.md) | Collect what is actually on the hosts and in the cluster, to check these docs against it |
| [TODO.md](TODO.md) | Open work that does not belong to one doc |

## Keeping them honest

- One fact, one place. Link to it instead of copying it.
- Write down intent and reasons, not observations. "Pinned to k3s-master because its data is a
  hostPath" holds for months. "Runs on k3s-master" is a `kubectl` question.
- A change that adds, removes or re-exposes an app also updates the Services table in the root
  `README.md` and `.claude/rules/services.md`.
- Gaps go in a "Still missing" section of the doc they belong to, not into memory.
