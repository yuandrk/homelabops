# Services & External Access

## Current Services

| Service | URL | Notes |
|---------|-----|-------|
| Immich | `photos.yuandrk.net` | Photo management, 500Gi NFS storage |
| ActualBudget | `budget.yuandrk.net` | Financial management |
| Headlamp | `headlamp.yuandrk.net` | K8s dashboard |
| n8n | `n8n.yuandrk.net` | Workflow automation, 5Gi storage, PostgreSQL backend |
| Grafana | `grafana.yuandrk.net` | Dashboards. Credentials live in the `grafana-admin-credentials` secret, not `admin/flux` |
| qBittorrent | `qbit.home.yuandrk.net` | Torrent client, tailnet only (see the naming rule below). Downloads to hostPath `/srv/media/downloads` on k3s-master |
| Fleet | `fleet.yuandrk.net` | osquery device management. Helm chart + its own MySQL (`fleet-mysql`, 8Gi local-path) and Valkey (`fleet-valkey`, no persistence), all pinned to k3s-worker3 — the Fleet image is amd64-only. Server URL and admin are set in the first-run wizard, not in the manifests. CVE scanning is off (`vulnProcessing.dedicated: false` + `FLEET_VULNERABILITIES_DISABLE_SCHEDULE`) |
| SearXNG | ClusterIP only | Metasearch for Hermes, in `hermes-sandbox`. No Ingress/NodePort by design — Hermes reaches it by ClusterIP from the k3s-master host. JSON API and `method: GET` are non-default and set in `searxng-settings.yml`; the limiter is off (it would reject programmatic requests) |
| browserless | ClusterIP only | Headless Chromium/CDP for Hermes, in `hermes-sandbox`. Every route needs `?token=` from the `hermes-sandbox-credentials` vault item |

> `hermes-sandbox` is the Hermes agent's workspace: PodSecurity baseline, default-deny network,
> quota with `persistentvolumeclaims: 0`, and a scoped `hermes-runner` account instead of the
> cluster-admin kubeconfig on k3s-master. Guardrail against mistakes, not a boundary against
> hostile code — no gVisor/Kata, so the node kernel is shared. See
> [hermes-sandbox.md](../../docs/hermes-sandbox.md).

> Deployed versions drift — check live with `kubectl get deploy -n apps -o wide` rather than trusting docs.
> Removed 2026-05-25: Uptime Kuma, pgAdmin, Ollama/open-webui (commit `f9a0fb9`).
> Removed 2026-08-01: Stirling-PDF (broken rollout, unused), MCP Slack Bot (unused).
> Removed 2026-08-01: Jellyfin (0 ingress requests in 14d), Whisper (0 `/v1/audio` requests ever
> in retained logs). Media files survive at hostPath `/srv/media` on k3s-master — only the
> `jellyfin-config` and `whisper-model-cache` PVCs were pruned.
> Removed 2026-08-08: Glance (dashboard on NodePort 30081, not wanted after a week). The
> `glance-credentials` vault item in 1Password outlives the manifest and is deleted by hand.

To decide whether an app is still used, query Traefik metrics rather than guessing — see
[usage-metrics.md](../../docs/usage-metrics.md).

## Infrastructure Services

- **PostgreSQL**: Native on k3s-worker3
- **FluxCD**: GitOps continuous deployment
- **Traefik**: K3s ingress controller
- **Monitoring Stack**: Prometheus (10Gi PVC, 15d retention), Grafana, Node Exporter, Kube State Metrics
- **Loki**: Log aggregation (10Gi PVC), with chunks-cache and results-cache
- **Alloy**: Log collector DaemonSet (runs on all nodes)
- **NFS Provisioner**: External storage provisioner in `storage` namespace (used by Immich)
- **NVIDIA Device Plugin**: GPU support on k3s-worker3 (GeForce MX130) — currently no GPU consumers
- **1Password Operator**: Secrets sync (`onepassword` namespace, HelmRelease in `flux-system`)

## Public vs internal: the hostname decides

| Suffix | Reachable from | How it is set up |
|--------|----------------|------------------|
| `<app>.yuandrk.net` | The internet | Append to `local.tunnel_services` in `terraform/live/homelab/cloudflare/main.tf` **and** set the Ingress host |
| `<app>.home.yuandrk.net` | Tailnet only | Just set the Ingress host — **no Terraform change** |

One DNS-only wildcard `*.home.yuandrk.net A → 100.96.117.64` (k3s-master's Tailscale address)
covers every internal service. `100.64.0.0/10` is CGNAT, so the name resolves publicly but only
a tailnet device can connect. There is no DNS server anywhere in this setup — do not add one to
solve internal naming.

Do **not** reach for a NodePort to make a service LAN-only; that was the old workaround from
when internal names did not resolve. Use a `.home.yuandrk.net` Ingress instead.

This gates names and routing, not access: Traefik listens on `0.0.0.0:80` on every node, so a
LAN device can still reach an internal app via `192.168.1.223` + `Host` header. Source-IP
allowlists do not work here (klipper masquerades the client IP — see memory
`klipper-masquerades-client-ip`). Full details: [network-architecture.md](../../docs/network-architecture.md).

## Cloudflare Tunnel Routing

cloudflared runs as a 2-replica HelmRelease in the `networking` namespace (see memory `cloudflared-in-cluster`). All tunnel ingresses target in-cluster Service DNS:

- `flux-webhook.yuandrk.net` → `http://webhook-receiver.flux-system.svc.cluster.local:80`
- Everything else → `http://traefik.kube-system.svc.cluster.local:80` (Traefik Service, port 80 → targetPort `web`/8000)
