# Services & External Access

## Current Services

| Service | URL | Notes |
|---------|-----|-------|
| Immich | `photos.yuandrk.net` | Photo management. Library on k3s-master `/srv/data/immich`, NFS-exported to `immich-server` on k3s-worker3 (it needs that node's iGPU). Static PV `immich-library-master`. See [backup.md](../../docs/backup.md) |
| ActualBudget | `budget.yuandrk.net` | Financial management. SQLite on hostPath `/srv/data/actualbudget`, pinned to k3s-master |
| Headlamp | `headlamp.yuandrk.net` | K8s dashboard |
| n8n | `n8n.yuandrk.net` | Workflow automation, 5Gi storage, PostgreSQL backend |
| Grafana | `grafana.yuandrk.net` | Dashboards. Credentials live in the `grafana-admin-credentials` secret, not `admin/flux` |
| qBittorrent | `qbit.home.yuandrk.net` | Torrent client, tailnet only (see the naming rule below). Downloads to hostPath `/srv/media/downloads` on k3s-master |
| Fleet | `fleet.yuandrk.net` | osquery device management. Helm chart + its own MySQL (`fleet-mysql`, 8Gi local-path) and Valkey (`fleet-valkey`, no persistence), all pinned to k3s-worker3 — the Fleet image is amd64-only. Server URL and admin are set in the first-run wizard, not in the manifests. CVE scanning is off (`vulnProcessing.dedicated: false` + `FLEET_VULNERABILITIES_DISABLE_SCHEDULE`) |
| Kite | `kite.yuandrk.net` | K8s dashboard (kite-org/kite), SQLite on 1Gi local-path, SA bound to `cluster-admin`. Okta OIDC (Web app, `client_secret_post`, callback `/api/auth/callback`), access = Okta app assignment to group `IT` (admin role mapped from the `groups` claim + by email). OAuth/RBAC/superUser come from the `kite-config` ConfigMap via `KITE_CONFIG_FILE`, so they are read-only in the UI — edit them in git. Local `admin` (password in `kite-credentials`) is the break-glass login |
| SearXNG | ClusterIP only | Metasearch for Hermes, in `hermes-sandbox`. No Ingress/NodePort by design — Hermes reaches it by ClusterIP from the k3s-master host. JSON API and `method: GET` are non-default and set in `searxng-settings.yml`; the limiter is off (it would reject programmatic requests) |
| browserless | ClusterIP only | Headless Chromium/CDP for Hermes, in `hermes-sandbox`. Every route needs `?token=` from the `hermes-sandbox-credentials` vault item |
| Hermes dashboard | `hermes.yuandrk.net` | **Not a pod** — a host process on k3s-master (`hermes-dashboard.service`, uvicorn :9119) fronted by a selector-less Service + hand-written EndpointSlice in the `hermes-dashboard` namespace. Auth is Okta OIDC via Hermes' own `self_hosted` provider and nothing else — `basic_auth` was removed, so there is no fallback if Okta is down. Access = Okta app assignment to `Andriuk corp`. Its config and systemd drop-in live on the host, outside git. See [hermes-dashboard.md](../../docs/hermes-dashboard.md) |

> `hermes-sandbox` is the Hermes agent's workspace: PodSecurity baseline, default-deny network,
> quota with `persistentvolumeclaims: 0`, and a scoped `hermes-runner` account instead of the
> cluster-admin kubeconfig on k3s-master. Guardrail against mistakes, not a boundary against
> hostile code — no gVisor/Kata, so the node kernel is shared. See
> [hermes-sandbox.md](../../docs/hermes-sandbox.md).

> Deployed versions drift — check live with `kubectl get deploy -n apps -o wide` rather than trusting docs.
> Removed apps, with dates, reasons and what each left behind: [decisions.md](../../docs/decisions.md#removed-apps).
> Add a line there when you remove one.

To decide whether an app is still used, query Traefik metrics rather than guessing — see
[usage-metrics.md](../../docs/usage-metrics.md).

## Infrastructure Services

- **PostgreSQL**: Native on k3s-worker3
- **FluxCD**: GitOps continuous deployment
- **Traefik**: K3s ingress controller
- **Monitoring Stack**: Prometheus (10Gi PVC, 15d retention), Grafana, Node Exporter, Kube State Metrics. Alertmanager is disabled. See [monitoring.md](../../docs/monitoring.md)
- **Loki**: Log aggregation, SingleBinary on a 10Gi PVC, caches off, no retention set
- **Alloy**: Log collector DaemonSet (runs on all nodes)
- **NFS Provisioner**: scaled to 0 and pending removal. Immich now uses a static NFS PV on k3s-master
- **Backups**: restic on the k3s-master host, nightly to k3s-worker1 and offsite to Backblaze B2 (bucket `homelab-backup-yuandrk`). See [backup.md](../../docs/backup.md)

> **k3s-worker1 is disposable.** It is tainted `homelab.yuandrk.net/disposable=true:NoSchedule` and
> runs only DaemonSets plus the restic repository. Never put anything important there (its USB-SSD
> hung on 2026-10-05 and took photos and budget down for five days). Important data goes to
> `/srv/data` on k3s-master, which the nightly backup covers.
- **GPU**: the NVIDIA device plugin was removed with Ollama (`db40da1`). The MX130 and its driver remain on k3s-worker3; revert that commit to schedule GPU work again
- **1Password Operator**: Secrets sync (`onepassword` namespace, HelmRelease in `flux-system`), polls every 6h. See [secrets.md](../../docs/secrets.md)

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
allowlists do not work here (klipper masquerades the client IP — see
[decisions.md](../../docs/decisions.md#2026-07-05--no-source-ip-allowlists)). Full details:
[network-architecture.md](../../docs/network-architecture.md).

## Cloudflare Tunnel Routing

cloudflared runs as a 2-replica HelmRelease in the `networking` namespace (see [decisions.md](../../docs/decisions.md#2026-05-24--cloudflared-moved-into-the-cluster)). All tunnel ingresses target in-cluster Service DNS:

- `flux-webhook.yuandrk.net` → `http://webhook-receiver.flux-system.svc.cluster.local:80`
- Everything else → `http://traefik.kube-system.svc.cluster.local:80` (Traefik Service, port 80 → targetPort `web`/8000)
