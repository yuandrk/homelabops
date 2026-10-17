# Decisions

Why things are the way they are: each entry is the decision, the reason and what it costs, with
the commits as evidence. The component docs hold the details. Newest first. Add an entry when a
change would make a future reader ask "why on earth…?".

## Standing decisions

- **Trunk-based on `main`, no staging.** A merge is a deploy: Flux deploys `main` and CI applies
  Terraform from it. Review is the only gate, and `main` has no branch protection to enforce it.
- **Terraform runs from CI only, and AWS trusts GitHub through OIDC**, so CI holds no AWS keys.
  The `homelab` environment has no required reviewers, so it is not a gate either. The one-time
  stacks were applied from a laptop ([terraform-guide.md](terraform-guide.md)).
- **Hermes runs outside k3s**, as user units on k3s-master, because the agent's control channel
  must work when the cluster does not. Its dashboard's public path still dies with the cluster
  ([hermes-dashboard.md](hermes-dashboard.md)).

## Log

### 2026-10-11 · No Flux webhook

`flux-webhook.yuandrk.net` had no `Receiver` behind it and GitHub never called it: Flux's
one-minute poll of `main` is what picks up merges. The route was removed rather than completed,
which leaves one public hostname fewer. [gitops.md](gitops.md#flux-kustomizations)

### 2026-10-11 · Custom alert rules removed until they have a purpose

`homelab-monitoring-rules` (18 alerts) lacked the `release: kube-prometheus-stack` label, so
Prometheus never loaded it, and with Alertmanager off it would have reached no one. It was
deleted rather than fixed; new rules come with a way to deliver them
([monitoring.md](monitoring.md#alerting-reaches-no-one)).

### 2026-10-10 · Important data on k3s-master, in three copies

On 2026-10-05 the USB-SSD of k3s-worker1 (a budget FIKWOT behind an ASMedia UAS bridge, with the
root filesystem on the same disk) stopped completing I/O while the kernel stayed up and the
journal stayed empty. Photos and the budget were down for five days, and the Immich library
existed only on that disk.

- **Decision:** irreplaceable data lives only under `/srv/data` on k3s-master's NVMe,
  k3s-worker1 is tainted `disposable`, and restic on the host copies everything nightly to
  worker1 and to Backblaze B2. Immich still computes on k3s-worker3 for the iGPU and reads its
  library over NFS (`sync`, so an acknowledged original is on disk).
- **Cost:** k3s-master is the single point of failure for the control plane and the data
  ([runbooks/rebuild-k3s-master.md](runbooks/rebuild-k3s-master.md)). The old worker1 PVCs stay
  bound as a rollback path.
- `c36a446`, `7520ed4`, `6f3f9c7`, `d1b40a8`, [backup.md](backup.md)

### 2026-09-26 · The cloudflare provider is pinned by a committed lock file

Without a lock file, every CI run resolved `~> 5.0` to the newest provider, and the new
`include_shadow_metadata` attribute of 5.26.0 failed the apply on `main`. The lock file is now
committed and Renovate bumps it in a PR, where the plan shows the effect first. It is the only
stack under Renovate because it is the only one CI applies. `9f8076c`,
[renovate-config.md](renovate-config.md#what-it-covers)

### 2026-09-26 · Kite's auth config lives in git

Kite reads OAuth, RBAC and its super-user from a ConfigMap (`KITE_CONFIG_FILE`) and shows them
read-only, so a login change is a reviewed commit, not a click nobody can trace. `51f5683`

### 2026-08-22 · Hermes dashboard on Okta as a public client, without a fallback

- **Public client with PKCE.** Given a client secret, Hermes sends HTTP Basic credentials and
  `client_id` in the body, which Okta rejects with a 401. Okta cannot turn a Web app into a
  Native one, so the app was recreated as Native.
- **`basic_auth` was removed** once SSO worked, because the dashboard is on the internet. If
  Okta is down, the way in is SSH.
- **Cost:** assignment to `Andriuk corp` is the only gate to the agent's control channel.
- `f1ac2b6`, `5fb7c00`, `b5a658e`, [hermes-dashboard.md](hermes-dashboard.md)

### 2026-08-17 · The hostname decides who can reach an app

The zone's proxied catch-all made every name resolve to Cloudflare, so internal apps needed
NodePorts. Now one DNS-only wildcard, `*.home.yuandrk.net`, points at k3s-master's Tailscale
address, which is CGNAT: it resolves anywhere but connects only from the tailnet. A public app is
a Terraform entry, an internal one only an Ingress host, and no DNS server is involved. `5bb5ef5`,
[network-architecture.md](network-architecture.md)

### 2026-08-15 · The Hermes sandbox is a guardrail, not a boundary

- The namespace **enforces** PodSecurity `baseline`, because `restricted` breaks `pip install`
  and every root-by-default image. `restricted` is the Job template's default instead, and the
  namespace audits it.
- **Every Job waits for its NetworkPolicy.** A short Job was measured running unfiltered before
  kube-router programmed its firewall, so an init container holds the workload until a
  connection the policy must block actually fails.
- **Cost:** no gVisor or Kata, so the kernel is shared, and Hermes can still read the admin
  kubeconfig on the host.
- `6733880`, `f1c27d2`, [hermes-sandbox.md](hermes-sandbox.md)

### 2026-08-14 · Fleet's MySQL and Valkey as plain manifests

The chart's MySQL subchart has no node selector and generates its password through a
live-cluster lookup, so it could strand its volume on the Pi. MySQL and Valkey are plain
manifests pinned to k3s-worker3, with the password in 1Password. CVE scanning is off: multi-GB
feed downloads and a memory burst. `2fdda8e`

### 2026-08-01 · Hosts are changed by hand, and the changes are written down

Ansible was bootstrap-only, untouched for a year, and its `k3s_install` role ran
`k3s-uninstall.sh` on any config change. It was removed, and host state is recorded in
[off-git.md](off-git.md). For the same reason k3s is upgraded by swapping the binary: the
install script drops flags that live only in the unit
([runbooks/upgrade-k3s.md](runbooks/upgrade-k3s.md)). `5cc1b2a`, `10a939b`

### 2026-08-01 · Renovate owns version bumps

Flux's image-reflector and image-automation controllers had nothing to act on, and one had 2,172
restarts. They were removed, and Renovate proposes every image, chart and Flux bump as a PR
([renovate-config.md](renovate-config.md)). `2159950`, `7810b01`

### 2026-08-01 · Apps are removed on usage data

Traefik already counts requests per service, so "is this still used?" is one query and a
dashboard ([monitoring.md](monitoring.md#is-an-app-still-used)). Jellyfin and Whisper were the
first removals it decided. `bbc161f`, `cfe1006`

### 2026-07-05 · No source-IP allowlists

k3s ServiceLB (klipper) masquerades the client address even with `externalTrafficPolicy: Local`,
so Traefik always sees the svclb pod. Replacing the load balancer is out of proportion for a home
media app, so "internal" means not in the tunnel and not in public DNS. The cost: anyone on the
home Wi-Fi can reach an internal app with the right `Host` header. Real per-service access
control would need the Tailscale Kubernetes operator. `42eeedf`

### 2026-05-25 · NVIDIA device plugin removed

Ollama, its only consumer, went the same day. The MX130 and its driver stay on k3s-worker3, and
`git revert db40da1` brings GPU scheduling back. `db40da1`, `f9a0fb9`

### 2026-05-24 · cloudflared moved into the cluster

It was a systemd service on the host, with tunnel routes to node ports. Two replicas now run in
`networking` and the routes name in-cluster Services, so pods can move without a Terraform
change. The cost: when the cluster is down, every public hostname is down too. `05daf7e`,
`f817e93`

### 2026-05-24 · No DNS server

Pi-hole was uninstalled from k3s-master; why was not recorded. The nodes resolve through
1.1.1.1 and 1.0.0.1, and internal names were later solved with DNS records instead of a
resolver (see 2026-08-17), so nothing local has to stay up for names to resolve. `5d1882c`

### 2026-05-17 · Secrets in 1Password instead of SOPS

All eight SOPS/age-encrypted Secrets moved to 1Password and reach the cluster through the
operator, so no key material lives in git or on a laptop, and one vault holds the cluster's and
the hosts' credentials. The costs are a hand-made bootstrap token and polling every 6 hours,
forced by the API rate limit (`9eea2a1`). `91b41dc`, [secrets.md](secrets.md)

### 2026-05-10 · Kubernetes login through Okta

Headlamp passes the user's Okta ID token to the k3s API server, which validates it, and RBAC
binds the user. That replaced a shared ServiceAccount token. Behind the tunnel it needed
`X-Forwarded-Proto: https` from a Traefik middleware, and PKCE. The issuer moved to the custom
domain on 2026-06-26 (`c21d197`). `eae210e`…`687fac3`, [access.md](access.md)

Headlamp was removed on 2026-10-11 ([removed apps](#removed-apps)), and with it the only user
of this login.

## Removed apps

| Date | App | Why | Left behind |
|------|-----|-----|-------------|
| 2026-10-17 | qBittorrent | Not wanted; 0 web UI requests in 14 days | 19 GB of downloads at `/srv/media` on k3s-master ([TODO](TODO.md#cleanup)) |
| 2026-10-11 | Headlamp | Not used; Kite covers the Kubernetes UI | the API server's OIDC flags on k3s-master, vault items `headlamp-oidc-okta` and `headlamp-token` ([TODO](TODO.md#cleanup)) |
| 2026-08-08 | Glance | Dashboard on NodePort 30081, not wanted after a week | nothing (its vault item was gone by 2026-10-11) |
| 2026-08-08 | Perlite | Read-only Obsidian vault viewer, not wanted after trying it | nothing (the vault was mounted read-only) |
| 2026-08-01 | Jellyfin | 0 ingress requests in 14 days | 16 GB of media at `/srv/media` on k3s-master |
| 2026-08-01 | Whisper | No `POST /v1/audio` in any retained log, only health probes | nothing |
| 2026-08-01 | Stirling-PDF | Unused, and stuck mid-rollout for 14 days | vault item `stirling-pdf-credentials` ([TODO](TODO.md#cleanup)) |
| 2026-08-01 | MCP Slack Bot | Unused | vault item `mcp-slack-bot-credentials` ([TODO](TODO.md#cleanup)) |
| 2026-05-25 | Uptime Kuma, pgAdmin, Ollama | No longer used | vault item `pgadmin-credentials` ([TODO](TODO.md#cleanup)) |
| 2025-11-15 | Authentik | No longer needed (Okta came in 2026-05) | vault item `headlamp-oidc-authentik` ([TODO](TODO.md#cleanup)) |
| 2025-08-30 | Jenkins | Not recorded | nothing |

Commits: `35a8413`, `1c0bdf7`, `cfe1006`, `5edce6a`, `f9a0fb9`, `7ae60cb`, `3668d49`.
