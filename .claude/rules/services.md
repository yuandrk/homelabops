# Services & External Access

## Current Services

| Service | URL | Notes |
|---------|-----|-------|
| Immich | `photos.yuandrk.net` | Photo management, 500Gi NFS storage |
| ActualBudget | `budget.yuandrk.net` | Financial management |
| Headlamp | `headlamp.yuandrk.net` | K8s dashboard |
| n8n | `n8n.yuandrk.net` | Workflow automation, 5Gi storage, PostgreSQL backend |
| Grafana | `grafana.yuandrk.net` | Dashboards. Credentials live in the `grafana-admin-credentials` secret, not `admin/flux` |
| qBittorrent | `qbit.yuandrk.net` | Torrent client, LAN/Tailscale only. Downloads to hostPath `/srv/media/downloads` on k3s-master |
| Fleet | `fleet.yuandrk.net` | osquery device management. Helm chart + its own MySQL (`fleet-mysql`, 8Gi local-path) and Valkey (`fleet-valkey`, no persistence), all pinned to k3s-worker3 — the Fleet image is amd64-only. Server URL and admin are set in the first-run wizard, not in the manifests. CVE scanning is off (`vulnProcessing.dedicated: false` + `FLEET_VULNERABILITIES_DISABLE_SCHEDULE`) |

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

## Cloudflare Tunnel Routing

cloudflared runs as a 2-replica HelmRelease in the `networking` namespace (see memory `cloudflared-in-cluster`). All tunnel ingresses target in-cluster Service DNS:

- `flux-webhook.yuandrk.net` → `http://webhook-receiver.flux-system.svc.cluster.local:80`
- Everything else → `http://traefik.kube-system.svc.cluster.local:80` (Traefik Service, port 80 → targetPort `web`/8000)
