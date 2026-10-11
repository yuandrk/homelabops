# Network

The physical network, how names resolve, and the three ways into the cluster. The short version
of the exposure rule is in [architecture.md](architecture.md#how-requests-get-in).

## Segments

| Network | Range | Notes |
|---------|-------|-------|
| Wired LAN | `10.10.0.0/24` | Unmanaged gigabit switch. Cluster traffic, NFS, PostgreSQL |
| Home Wi-Fi | `192.168.1.0/24` | BT router. Internet access for k3s-master and k3s-worker1 (k3s-master's uplink is about 73 Mbit/s) |
| Tailnet | `100.64.0.0/10` | Only k3s-master is a member. It routes the tailnet into the wired LAN |
| Pods | `10.42.0.0/16` | Flannel VXLAN, one `/24` per node |
| Services | `10.43.0.0/16` | ClusterIP. CoreDNS is `10.43.0.10` |

The wired LAN carries cluster traffic and the Wi-Fi carries internet traffic. There is no NAT
between the two. k3s-worker3 is wired only, and the route it takes to the internet is
[not recorded](off-git.md#k3s-worker3).

## Nodes

| Node | Wired | Wi-Fi | Hardware |
|------|-------|-------|----------|
| `k3s-master` | `10.10.0.1` | `192.168.1.223` | Intel i3-7100U, 16 GB, 1 TB NVMe |
| `k3s-worker1` | `10.10.0.2` | `192.168.1.137` | Raspberry Pi 4, 4 GB, 1 TB USB-SSD |
| `k3s-worker3` | `10.10.0.5` | none | x86-64, 16 GB, Intel iGPU + NVIDIA MX130 |

`k3s-worker2` (RPi 4, `10.10.0.4`) was decommissioned in May 2026.

```txt
             BT router, 192.168.1.0/24 ── internet
                  │ Wi-Fi          │ Wi-Fi
            [k3s-master]      [k3s-worker1]
             .223               .137
                  │                │
 ═════════ wired LAN 10.10.0.0/24, unmanaged gigabit switch ═════════
                  │                │                │
            [k3s-master]      [k3s-worker1]    [k3s-worker3]
                .1               .2               .5
```

## Listening ports

| Node | Port | Service | Reachable from |
|------|------|---------|----------------|
| every node | 80, 443 | Traefik through k3s ServiceLB (svclb) | LAN, and tailnet through k3s-master |
| every node | 2222 | SSH, keys only | LAN |
| k3s-master | 6443 | Kubernetes API | LAN, tailnet |
| k3s-master | 2049 | NFS, Immich library export to `10.10.0.5` only | wired LAN |
| k3s-master | 9119 | Hermes dashboard, a host process | LAN, tailnet, and Traefik as `hermes.yuandrk.net` |
| k3s-worker3 | 5432 | PostgreSQL, native | LAN and pods |
| any node | 30283 | Immich NodePort, for the mobile app on the LAN | LAN |

UFW is disabled on every node.

## Tailscale

k3s-master is a Tailscale node **and** a subnet router. Nothing else in the cluster runs
Tailscale — workers are not on the tailnet.

| Property | Value |
|----------|-------|
| Tailnet | `tail1fbf9e.ts.net` |
| k3s-master tailnet address | `100.96.117.64` |
| Advertised subnet route | `10.10.0.0/24` (the wired switch LAN) |
| MagicDNS | Enabled (resolver `100.100.100.100`) |

The subnet route is what makes the wired-only nodes reachable from outside that switch:
`k3s-worker3` (10.10.0.5) has no Wi-Fi interface, yet a tailnet device can reach it directly.

`tailscaled` on k3s-master is a host-level systemd service, not managed by Flux.

> MagicDNS names (`k3s-master.tail1fbf9e.ts.net`) resolve **only** through `100.100.100.100`.
> They are not in public DNS, so they cannot be used as a CNAME target from Cloudflare.

## DNS

There are three ways to reach a service, and the hostname says which one applies:

| Path | Hostname | Resolves to | Who can reach it |
|------|----------|-------------|------------------|
| Cloudflare tunnel | `<app>.yuandrk.net` | Cloudflare proxy IPs | The internet |
| Tailscale | `<app>.home.yuandrk.net` | `100.96.117.64` | Tailnet devices only |
| Direct | — | `192.168.1.223` / `10.10.0.1` | Home LAN |

### Split-horizon without a DNS server

The zone has a catch-all `*.yuandrk.net A → <Cloudflare proxy>` (proxied, created by hand, not in
Terraform), so **every** name in the zone resolves to Cloudflare unless a more specific record
overrides it. The tunnel has ingress rules for the public services and a terminal
`http_status:404`, so any other name is publicly dead.

Internal services are carved out by one DNS-only wildcard, managed in
`terraform/live/homelab/cloudflare/main.tf` as `cloudflare_dns_record.internal_wildcard`:

```
*.home.yuandrk.net  A  100.96.117.64   (proxied = false, TTL 300)
```

`100.64.0.0/10` is CGNAT and unroutable across the internet, so the name resolves everywhere
but only a tailnet device can actually connect. Per RFC 4592 the closest wildcard wins, so
`*.home.yuandrk.net` beats `*.yuandrk.net` for anything under `home.`.

**No DNS server is involved.** A local resolver (Pi-hole) was removed in May 2026 and is not
needed for this: the split is done with records, not with a service that can go down.

Adding a service:
- **public** → append an object to `local.tunnel_services` in Terraform, Ingress host `<name>.yuandrk.net`
- **internal** → Ingress host `<name>.home.yuandrk.net`, no Terraform change at all

> This separates names and routing, not permissions. Traefik still listens on `0.0.0.0:80` on
> every node, so anything on the home Wi-Fi can reach an internal app by hitting
> `192.168.1.223` with the right `Host` header. Source-IP filtering on Traefik is not an
> option here — klipper (k3s ServiceLB) unconditionally masquerades the client address, which
> is why an earlier `ipAllowList` attempt was reverted in `42eeedf`. Real per-service access
> control would mean the Tailscale Kubernetes operator.

### Resolver chain

```
Host nodes (k3s-master, workers)
        ↓
   systemd-resolved
   └─ Upstream: 1.1.1.1, 8.8.8.8 (fallback: 9.9.9.9)

K3s Pods
        ↓
   CoreDNS (cluster service 10.43.0.10:53)
   ├─ Service discovery (.cluster.local)
   ├─ Node hostnames via NodeHosts plugin (k3s-master → 10.10.0.1, etc.)
   └─ forward . /etc/resolv.conf  (i.e. via the node's systemd-resolved)
```

Pods have no tailnet membership, so a pod resolving `<app>.home.yuandrk.net` gets
`100.96.117.64` and cannot connect. If a pod ever needs to call an internal service by name,
k3s's stock hook is a `coredns-custom` ConfigMap in `kube-system` — the live Corefile already
ends with `import /etc/coredns/custom/*.override` and `import /etc/coredns/custom/*.server`.
That ConfigMap does not exist today; nothing currently needs it.

### DNS Configuration

#### systemd-resolved Override (All Nodes)
```ini
# /etc/systemd/resolved.conf.d/homelab.conf
[Resolve]
DNS=1.1.1.1 8.8.8.8
FallbackDNS=9.9.9.9
Domains=~.
```

Cluster node hostnames are mirrored in `/etc/hosts` on every node so `ssh k3s-worker1` etc. resolve without DNS:
```
10.10.0.1 k3s-master
10.10.0.2 k3s-worker1
10.10.0.5 k3s-worker3
```

## Cloudflare Tunnel

| | |
|---|---|
| Tunnel | `homeserver`, ID `4a6abf9a-d178-4a56-9586-a3d77907c5f1`. The tunnel itself was created outside Terraform |
| Routes | `local.tunnel_services` in `terraform/live/homelab/cloudflare/main.tf`, ending in `http_status:404` |
| Backends | `traefik.kube-system.svc.cluster.local:80` for every app. `flux-webhook.yuandrk.net` goes to `webhook-receiver.flux-system.svc.cluster.local:80` |
| Connector | `cloudflared` HelmRelease, 2 replicas, namespace `networking`, token from 1Password |

## Commands

### Network Diagnostics
```bash
# Test internal connectivity
ping k3s-worker1              # Resolves via /etc/hosts
resolvectl query k3s-master   # DNS resolution test

# Check K3s network
kubectl get nodes -o wide     # Node IPs and status
kubectl get pods -o wide -A   # Pod distribution across nodes

# Performance testing
iperf3 -c k3s-worker1 -t 5    # Bandwidth test
ping -c 10 k3s-worker3        # Latency test
```

### DNS Management
```bash
# systemd-resolved on host nodes
systemctl restart systemd-resolved
resolvectl status              # Show active DNS servers
resolvectl flush-caches        # Clear host DNS cache

# CoreDNS in-cluster
kubectl rollout restart -n kube-system deploy/coredns
kubectl get cm -n kube-system coredns -o yaml
```

