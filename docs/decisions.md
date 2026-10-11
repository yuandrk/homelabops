# Decisions

Why things are the way they are. Each entry is the decision, the reason, and what it costs,
with the commits as evidence. The component docs hold the details. This page is the index of
the reasoning, so it does not end up living only in someone's head or in an agent's memory.

Newest first. Add an entry when a change would make a future reader ask "why on earth…?".

## Standing decisions

- **Trunk-based on `main`, no staging.** Feature branches and Renovate PRs merge into `main`.
  Flux deploys `main`, and CI applies Terraform from it. There is one environment, so a merge
  is a deploy. The cost is that a bad merge lands in production, and review is the only gate.
  Nothing enforces that review: `main` has no branch protection.
- **Terraform runs from CI only, and AWS trusts GitHub through OIDC.** CI holds no AWS keys.
  Plans are commented on PRs, and applies run on merge. The apply job uses the `homelab`
  environment, but that environment has no required reviewers, so it is not a gate. The
  exceptions are the one-time stacks (`aws-bootstrap`, `aws-oidc`, `fluxcd`), applied from a
  laptop ([terraform-guide.md](terraform-guide.md)).
- **Hermes runs outside k3s.** It is the agent's control channel, so it has to work when the
  cluster does not. It runs as user systemd units on k3s-master. Its dashboard is published
  through the cluster anyway, and that public path dies with the cluster
  ([hermes-dashboard.md](hermes-dashboard.md)).

## Log

### 2026-10-11 · No Flux webhook

`flux-webhook.yuandrk.net` was published through the tunnel to Flux's `webhook-receiver`
Service, but no `Receiver` was ever created and GitHub never called it. Nothing used it: Flux's
one-minute poll of `main` is what picks up merges. The route was removed rather than completed,
which leaves one public hostname fewer. [gitops.md](gitops.md#flux-kustomizations)

### 2026-10-11 · Custom alert rules removed until they have a purpose

`homelab-monitoring-rules` (18 alerts) lacked the `release: kube-prometheus-stack` label, so
Prometheus never loaded it, and with Alertmanager off it would have reached no one anyway.
Rather than fix rules nobody had chosen, they were deleted. New rules get written for what
actually needs attention, together with a way to deliver them
([monitoring.md](monitoring.md#alerting-reaches-no-one)).

### 2026-10-10 · Important data on k3s-master, in three copies

The USB-SSD of k3s-worker1 hung on 2026-10-05 and took photos and the budget down for five
days. The Immich library existed in one copy, on that disk.

- **Decision:** irreplaceable data lives only on k3s-master's NVMe under `/srv/data`.
  k3s-worker1 is tainted `disposable` and holds only the backup repository. restic copies
  everything nightly to worker1 and to Backblaze B2.
- **Immich** still computes on k3s-worker3 for the iGPU and reads its library over NFS
  (`sync`, because originals must be on disk once acknowledged).
- **restic runs on the host**, because a restore must not depend on a healthy cluster.
- **Cost:** k3s-master is now the single point of failure for both the control plane and the
  data ([runbooks/rebuild-k3s-master.md](runbooks/rebuild-k3s-master.md)). The old worker1 PVCs
  are still bound as a rollback path.
- `c36a446`, `7520ed4`, `6f3f9c7`, `d1b40a8`, [backup.md](backup.md)

### 2026-09-26 · The cloudflare provider is pinned by a committed lock file

The lock file was gitignored, so every CI run resolved `~> 5.0` to the newest provider. On
2026-09-26 that was 5.26.0, whose new `include_shadow_metadata` attribute failed the apply on
`main`. The stack's `.terraform.lock.hcl` is now committed, and Renovate bumps it in a
`terraform-cloudflare` PR, where `terraform-plan.yml` shows the effect before `main` sees it.
It is the only stack under Renovate because it is the only one CI applies. `9f8076c`,
[renovate-config.md](renovate-config.md#what-it-covers)

### 2026-09-26 · Kite's auth config lives in git

Kite reads OAuth, RBAC and its super-user from a ConfigMap through `KITE_CONFIG_FILE`. The UI
shows these settings read-only. A login change is a reviewed commit, not a click that nobody
can trace. `51f5683`

### 2026-08-22 · Hermes dashboard on Okta as a public client, without a fallback

- **Public client with PKCE, not a confidential one.** Hermes chooses its token-endpoint auth
  method from what the IdP advertises. Okta advertises both `client_secret_basic` and
  `client_secret_post`, so Hermes picks HTTP Basic while still sending `client_id` in the body,
  and Okta rejects that with a 401. The Okta app had to be recreated as a Native app.
- **`basic_auth` was removed** once SSO worked, because the dashboard is reachable from the
  internet. If Okta is down, the way in is SSH.
- **Cost:** access is "assigned to `Andriuk corp` in Okta". Adding someone to that group gives
  them the agent's control channel, with no second gate.
- `f1ac2b6`, `5fb7c00`, `b5a658e`, [hermes-dashboard.md](hermes-dashboard.md)

### 2026-08-17 · The hostname decides who can reach an app

The zone had a proxied catch-all, so every name resolved to Cloudflare, and internal apps
needed NodePorts. Now one DNS-only wildcard, `*.home.yuandrk.net`, points at k3s-master's
Tailscale address (CGNAT, so it resolves anywhere but only connects from the tailnet). A
public app is a Terraform entry, and an internal one needs only its Ingress host. No DNS server
is involved: the split is made of DNS records, not a service that can go down. `5bb5ef5`,
[network-architecture.md](network-architecture.md)

### 2026-08-15 · The Hermes sandbox is a guardrail, not a boundary

- The namespace **enforces** PodSecurity `baseline`, not `restricted`. Baseline blocks what
  protects the node. Restricted breaks `pip install` and every root-by-default image, so it is
  applied in the Job template as a default the caller opts out of, and audited in the namespace.
- **Every Job waits for its NetworkPolicy.** kube-router programs a pod's firewall only after
  it sees the pod, so a short Job ran unfiltered for its first seconds. That was measured, not
  guessed. An init container now holds the workload until a connection that the policy must
  block actually fails.
- **Cost:** no gVisor or Kata, so the kernel is shared. Hermes can still read the admin
  kubeconfig on the host.
- `6733880`, `f1c27d2`, [hermes-sandbox.md](hermes-sandbox.md)

### 2026-08-14 · Fleet's MySQL and Valkey as plain manifests

The chart's MySQL subchart has no node selector and generates its password through a
live-cluster lookup. An unconstrained StatefulSet could strand its volume on the Pi for good.
So MySQL and Valkey are plain manifests pinned to k3s-worker3, with the password in 1Password.
CVE scanning is off, because it means multi-GB feed downloads and a memory burst. `2fdda8e`

### 2026-08-01 · Hosts are changed by hand, and the changes are written down

Ansible was bootstrap-only and had not been touched for a year. Its `k3s_install` role hashed
the config, version included, and ran `k3s-uninstall.sh` on any change, which wipes
`/var/lib/rancher/k3s`. It was removed, and host state is now recorded in
[off-git.md](off-git.md). In the same spirit, k3s is upgraded by swapping the binary, because
the install script drops flags that exist only in the systemd unit
([runbooks/upgrade-k3s.md](runbooks/upgrade-k3s.md)). `5cc1b2a`, `10a939b`

### 2026-08-01 · Renovate owns version bumps

Flux's image-reflector and image-automation controllers ran with zero resources to act on, and
one of them had 2,172 restarts. They were removed, and the Terraform bootstrap no longer
reinstates them. Renovate proposes every image, chart and Flux bump as a PR
([renovate-config.md](renovate-config.md)). `2159950`, `7810b01`

### 2026-08-01 · Apps are removed on usage data

Traefik already counts requests per service, so "is this still used?" became one query and a
dashboard ([usage-metrics.md](usage-metrics.md)). Jellyfin and Whisper were the first removals
decided by it. `bbc161f`, `cfe1006`

### 2026-07-05 · No source-IP allowlists

k3s ServiceLB (klipper) masquerades the client address unconditionally, so Traefik always sees
the svclb pod, even with `externalTrafficPolicy: Local`. Making allowlists work would mean
replacing the load balancer, which is out of proportion for a home media app. "Internal" means
not in the tunnel and no public DNS. The cost is that anyone on the home Wi-Fi can reach an
internal app with the right `Host` header. `42eeedf`

### 2026-05-25 · NVIDIA device plugin removed

Ollama was its only consumer and was removed the same day. The MX130 and its driver stay on
k3s-worker3. `git revert db40da1` brings GPU scheduling back. `db40da1`, `f9a0fb9`

### 2026-05-24 · cloudflared moved into the cluster

It was a systemd service on the host, with tunnel routes to `k3s-master:80` and
`k3s-worker1:30080`. Now two replicas run in the `networking` namespace, and the routes name
in-cluster Services, so pods can move without a Terraform change. The cost is that when the
cluster is down, every public hostname is down with it. `05daf7e`, `f817e93`

### 2026-05-24 · No DNS server

Pi-hole was uninstalled from k3s-master. The nodes use systemd-resolved straight to 1.1.1.1 and
8.8.8.8, and internal names were later solved with DNS records instead of a resolver (see
2026-08-17). `5d1882c`

### 2026-05-17 · Secrets in 1Password instead of SOPS

All eight SOPS/age-encrypted Secrets moved to 1Password and reach the cluster through the
1Password Operator. No key material lives in git or on a laptop any more, and one vault holds
both the cluster's and the hosts' credentials. The costs:

- a hand-made bootstrap token;
- the 1Password API rate limit, which forced polling every 6 hours (`9eea2a1`), so a changed
  secret takes up to six hours to arrive.

`91b41dc`, [secrets.md](secrets.md)

### 2026-05-10 · Kubernetes login through Okta

Headlamp authenticates users against the k3s API server with Okta ID tokens. The API server
validates them, and RBAC binds the Okta user. Before that, Headlamp logins used a shared
ServiceAccount token. Behind the tunnel this needed `X-Forwarded-Proto: https` from a Traefik
middleware and PKCE. The issuer moved to the custom domain on 2026-06-26 (`c21d197`).
`eae210e`…`687fac3`, [access.md](access.md)

## Removed apps

| Date | App | Why | Left behind |
|------|-----|-----|-------------|
| 2026-08-08 | Glance | Dashboard on NodePort 30081, not wanted after a week | 1Password item `glance-credentials`, to delete by hand |
| 2026-08-08 | Perlite | Read-only Obsidian vault viewer, not wanted after trying it | nothing (the vault was mounted read-only) |
| 2026-08-01 | Jellyfin | 0 ingress requests in 14 days | 16 GB of media at `/srv/media` on k3s-master |
| 2026-08-01 | Whisper | No `POST /v1/audio` in any retained log, only health probes | nothing |
| 2026-08-01 | Stirling-PDF | Unused, and stuck mid-rollout for 14 days | nothing |
| 2026-08-01 | MCP Slack Bot | Unused | nothing |
| 2026-05-25 | Uptime Kuma, pgAdmin, Ollama | No longer used | nothing |
| 2025-11-15 | Authentik | No longer needed (Okta came in 2026-05) | 1Password item `headlamp-oidc-authentik`, still pulled into `flux-system` ([secrets.md](secrets.md#what-is-in-the-vault)) |
| 2025-08-30 | Jenkins | Not recorded | nothing |

Commits: `35a8413`, `1c0bdf7`, `cfe1006`, `5edce6a`, `f9a0fb9`, `7ae60cb`, `3668d49`.
