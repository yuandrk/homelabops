# Architecture

Three nodes, one control plane. Flux applies the cluster from `main`, CI applies the Cloudflare
edge with Terraform, and a few services run on the hosts outside Kubernetes on purpose.

This page holds what stays true from week to week. For what is running right now, ask the
cluster (`flux get all -A`, `kubectl get pods -A -o wide`), not the docs. For why things are
the way they are, see [decisions.md](decisions.md).

## Principles

1. **The cluster is what `main` says.** Flux applies it and reverts hand edits. The few things
   it cannot hold are listed in [off-git.md](off-git.md).
2. **The hostname decides who can reach an app.** `<app>.yuandrk.net` is public through the
   Cloudflare Tunnel, `<app>.home.yuandrk.net` is tailnet-only. Public traffic arrives over an
   outbound tunnel, so the design needs no port forwarding on the router.
3. **Secrets live in 1Password**, never in git, encrypted or not ([secrets.md](secrets.md)).
4. **Irreplaceable data lives on k3s-master and nowhere else**, and every night it gets two more
   copies: on k3s-worker1 and in Backblaze B2 ([backup.md](backup.md)).
5. **k3s-worker1 is disposable.** It is tainted and runs only DaemonSets and the backup repository.
6. **What must survive a broken cluster runs on the host**: the backups, Tailscale and the
   Hermes agent.
7. **An app stays only while it is used.** It is removed on Traefik request data, not on memory
   ([usage-metrics.md](usage-metrics.md)).
8. **Terraform runs from CI**: plan on the PR, apply on merge to `main`.

## Nodes

| Node | Hardware | Network | Role |
|------|----------|---------|------|
| `k3s-master` | Intel i3-7100U, 16 GB, 1 TB NVMe | `10.10.0.1` wired, `192.168.1.223` Wi-Fi, `100.96.117.64` Tailscale | Control plane, important data under `/srv/data`, NFS server, Tailscale subnet router, restic, Hermes |
| `k3s-worker3` | Intel i5-8265U, 16 GB, 512 GB NVMe, Intel iGPU + NVIDIA MX130 | `10.10.0.5` wired, `192.168.1.246` Wi-Fi | The heavy worker: Immich compute, Fleet, Prometheus, Loki, the Hermes sandbox. Native PostgreSQL |
| `k3s-worker1` | Raspberry Pi 4, 4 GB, 1 TB USB SSD | `10.10.0.2` wired, `192.168.1.137` Wi-Fi | Disposable: DaemonSets only, plus the local restic repository |

The wired LAN is an unmanaged gigabit switch. Each node reaches the internet over its own
home Wi-Fi link ([network-architecture.md](network-architecture.md)).

## What is pinned, and why

Most workloads go wherever the scheduler puts them. Note that a `local-path` volume pins its
pod to the node where the volume was first created. These are pinned on purpose:

| Workload | Node | Why |
|----------|------|-----|
| ActualBudget, qBittorrent | k3s-master | Their data is a hostPath under `/srv/data` and `/srv/media` |
| Immich server, machine learning, Valkey | k3s-worker3 | The server uses the Intel iGPU for hardware transcoding. The library comes over NFS from k3s-master |
| Fleet, its MySQL and Valkey | k3s-worker3 | The Fleet image is amd64-only, and MySQL on `local-path` must not land on the Pi |
| Hermes sandbox jobs and services | k3s-worker3 | The only node with real headroom |
| Prometheus, Grafana, prometheus-operator | amd64 nodes | Memory |
| Everything except DaemonSets | not k3s-worker1 | Taint `homelab.yuandrk.net/disposable=true:NoSchedule` |

## How requests get in

```mermaid
flowchart LR
    internet(["Internet"]) --> edge["Cloudflare edge<br/>TLS for *.yuandrk.net"]
    cloudflared["cloudflared x2<br/>networking namespace"] -->|"outbound tunnel"| edge
    edge -.->|"requests ride the tunnel"| cloudflared
    cloudflared --> traefik["Traefik"]
    tailnet(["Tailnet device"]) -->|"*.home.yuandrk.net<br/>resolves to 100.96.117.64"| master["k3s-master<br/>Tailscale"]
    master --> traefik
    lan(["Home LAN"]) -->|"192.168.1.223<br/>+ Host header"| traefik
    traefik --> apps["Ingress, Service, Pod"]
    traefik --> hermes["Hermes dashboard<br/>host process on :9119"]
```

- **Public**: an `<app>.yuandrk.net` CNAME points at the tunnel. cloudflared has dialed out to
  Cloudflare and forwards to in-cluster Service DNS, so no node address or NodePort appears in
  the tunnel config. Adding one is an entry in `local.tunnel_services` in Terraform.
- **Tailnet**: one DNS-only wildcard, `*.home.yuandrk.net`, resolves to k3s-master's Tailscale
  address. It resolves anywhere, but only a tailnet device can connect. No Terraform change is
  needed per app.
- **LAN**: Traefik listens on every node, so the home Wi-Fi can reach any app by IP plus `Host`
  header. The hostname split controls names and routing, not permissions
  ([network-architecture.md](network-architecture.md#split-horizon-without-a-dns-server)).
- **Exception**: the Hermes dashboard is a host process behind a selector-less Service
  ([hermes-dashboard.md](hermes-dashboard.md)).

## How changes get in

```mermaid
flowchart LR
    branch["Feature branch<br/>or Renovate PR"] --> pr["Pull request"]
    pr -->|"terraform/ changed"| plan["terraform-plan<br/>comments the plan"]
    pr -->|"merge"| main["main"]
    main --> flux["Flux<br/>polls every minute"]
    flux --> cluster[("k3s cluster")]
    main -->|"terraform/ changed"| apply["terraform-apply<br/>runs on merge"]
    apply --> cf["Cloudflare<br/>DNS, tunnel routes"]
    vault["1Password<br/>vault homelab"] --> operator["1Password operator<br/>syncs every 6 h"]
    operator --> cluster
```

Development is trunk-based. There is no `dev` branch and no staging: a merge to `main` is a
deploy. See [gitops.md](gitops.md), [terraform-guide.md](terraform-guide.md) and
[renovate-config.md](renovate-config.md).

## Where data lives

```mermaid
flowchart LR
    subgraph master["k3s-master"]
        data["/srv/data<br/>Immich library, ActualBudget"]
        pvcs["local-path volumes<br/>n8n, Kite, qBittorrent config"]
        restic["restic<br/>systemd timers"]
    end
    subgraph worker3["k3s-worker3"]
        immich["immich-server"]
        pg[("PostgreSQL<br/>Immich, n8n")]
    end
    immich -->|"NFS"| data
    immich --> pg
    data --> restic
    pvcs --> restic
    restic -->|"05:30, SFTP"| local[("k3s-worker1<br/>restic repository")]
    restic -->|"06:15, S3 API"| b2[("Backblaze B2")]
```

Not covered: n8n's database in PostgreSQL, the local-path volumes on k3s-worker3 (Fleet's
MySQL, Prometheus, Loki), and Hermes' home directory on k3s-master, see [backup.md](backup.md)
and [off-git.md](off-git.md).

## Outside the cluster on purpose

| Service | Host | Why not in k3s |
|---------|------|----------------|
| restic | k3s-master | A restore must not depend on a healthy cluster |
| Tailscale | k3s-master | It is the way in when other things are broken |
| Hermes agent and dashboard | k3s-master | The agent's control channel must keep working when the cluster does not |

PostgreSQL on k3s-worker3 is a native install too, but the reason for that is not recorded.

## Further reading

- [access.md](access.md): who logs in where, and the way in when Okta is down
- [monitoring.md](monitoring.md): metrics, logs, dashboards, and the alerting gap
- [hermes-sandbox.md](hermes-sandbox.md): the agent's scoped workspace in the cluster
