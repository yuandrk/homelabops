# 🌐 Homelab Network Architecture

**Status**: ✅ K3s cluster operational with dual networking setup
**Last Updated**: June 11, 2026
**Cluster**: 3-node K3s cluster (1 master + 2 workers)

---

## 🏗️ Network Overview

### Network Segments
- **Host LAN**: `10.10.0.0/24` (wired via unmanaged switch)
- **Host Wi-Fi**: `192.168.1.0/24` (via BT router for internet)
- **K3s Pod Network**: `10.42.0.0/16` (Flannel CNI)
- **K3s Service Network**: `10.43.0.0/16` (ClusterIP services)

### Routing Strategy
- **Internal Communication**: Direct LAN (10.10.0.x) for cluster traffic
- **Internet Access**: Wi-Fi fallback (192.168.1.x) for external connectivity
- **No NAT** between networks - coexistence model

---

## 🖥️ Node Configuration

| Node | Hostname | Host LAN IP | Wi-Fi IP | Role | Key Services |
|------|----------|-------------|----------|------|--------------|
| **Master** | `k3s-master` | 10.10.0.1/24 | 192.168.1.223 | Control Plane | K3s Server, Traefik |
| **Worker 1** | `k3s-worker1` | 10.10.0.2/24 | 192.168.1.137 | Worker Node | K3s Agent |
| **Worker 3** | `k3s-worker3` | 10.10.0.5/24 | - | Worker Node | PostgreSQL (Native), K3s Agent, GPU |

### Hardware Specs
- **k3s-master**: Intel i3-7100U, 15 GiB RAM, 931 GiB NVMe (x86-64)
- **k3s-worker1**: ARM64 RPi 4, 3.7 GiB RAM, 954 GiB USB-SSD
- **k3s-worker3**: x86_64, NVIDIA GeForce MX130 (2GB VRAM), CUDA 12.2

> `k3s-worker2` (RPi 4, 10.10.0.4) was decommissioned in May 2026.

---

## 📡 Network Topology

```txt
┌─────────────────┐
│   BT Wi-Fi      │ 🌐 Internet Access
│   (Router)      │ 192.168.1.0/24
└────────┬────────┘
         │
    Wi-Fi Cloud ☁️
    ┌────┴────┐
    │         │
[k3s-master] [worker1]
192.168.1.223 .137
    │         │
    │         │
════════════════════════════════════
    │ 10.10.0.0/24 LAN │ ⚡ Gigabit
════════════════════════════════════
    │    │    │
  .1/24 .2/24 .5/24
[k3s-master] [worker1] [worker3]
    │    │    │
    └────┴────┘
   [Unmanaged Switch]

K3s Pod Networks (Flannel):
└─ One 10.42.x.0/24 subnet per node (see `kubectl get nodes -o custom-columns=NAME:.metadata.name,CIDR:.spec.podCIDR`)

K3s Services: 10.43.0.0/16
```

---

## 🚦 Port Mapping & Services

### k3s-master (10.10.0.1)
| Service | Port | Protocol | Access | Notes |
|---------|------|----------|--------|-------|
| **Traefik** | 80, 443 | HTTP/HTTPS | LAN + External | K3s ingress controller |
| **K3s API** | 6443 | HTTPS | Internal | Kubernetes API server |
| **SSH** | 2222 | TCP | LAN | Hardened SSH port |

### k3s-worker1 (10.10.0.2)
| Service | Port | Protocol | Access | Notes |
|---------|------|----------|--------|-------|
| **SSH** | 2222 | TCP | LAN | Hardened SSH port |
| **systemd-resolved** | 53 | UDP | Local | Local DNS stub |

### k3s-worker3 (10.10.0.5)
| Service | Port | Protocol | Access | Notes |
|---------|------|----------|--------|-------|
| **SSH** | 2222 | TCP | LAN | Hardened SSH port |
| **PostgreSQL** | 5432 | TCP | LAN | Native install (not K3s-managed) |
| **systemd-resolved** | 53 | UDP | Local | Local DNS stub |

---

## 🔒 Tailscale

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

---

## 🌍 DNS Architecture

There are three ways to reach a service, and the hostname says which one applies:

| Path | Hostname | Resolves to | Who can reach it |
|------|----------|-------------|------------------|
| Cloudflare tunnel | `<app>.yuandrk.net` | Cloudflare proxy IPs | The internet |
| Tailscale | `<app>.home.yuandrk.net` | `100.96.117.64` | Tailnet devices only |
| Direct | — | `192.168.1.223` / `10.10.0.1` | Home LAN |

### Split-horizon without a DNS server

The zone has a catch-all `*.yuandrk.net A → <Cloudflare proxy>` (proxied), so **every** name
in the zone resolves to Cloudflare unless a more specific record overrides it. The tunnel has
ingress rules for the public services and a terminal `http_status:404`, so any other name is
publicly dead.

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

---

## 📈 Network Performance

### Measured Performance (August 2025)
| Connection Type | Latency | Bandwidth | Use Case |
|----------------|---------|-----------|----------|
| **Worker ↔ Worker** | 0.4ms | 932 Mbps | Pod-to-pod, storage replication |
| **Master ↔ Workers** | 6-9ms | 60 Mbps | Control plane, kubectl |
| **Internet Access** | ~50ms | 14-19 Mbps | Image pulls, external APIs |

### Performance Tiers
1. **🥇 Direct LAN**: Gigabit speeds between workers (excellent for workloads)
2. **🥈 Wi-Fi Mesh**: Good for control plane traffic  
3. **🥉 Internet**: Typical home broadband performance

---

## 🔧 K3s Integration Notes

### K3s Networking Features
- **CNI**: Flannel VXLAN for pod networking
- **Service Mesh**: ClusterIP services via kube-proxy
- **Load Balancer**: Traefik for ingress traffic
- **API Access**: Uses `k3s_install_api_endpoint: 10.10.0.1:6443` for reliability

---

## 🛡️ Security Configuration

### Network Security
- **SSH Hardening**: All nodes use port 2222 with key-based auth
- **Firewall**: Currently disabled (UFW=off) - LAN-only access
- **Tunnel Security**: Cloudflare tunnels for secure external access

### Access Control
- **Internal Only**: Most services only accessible via LAN
- **External Access**: Limited to specific services via Cloudflare tunnels
- **Service Isolation**: K3s network policies can be implemented as needed

---

## 🚀 External Services & Tunnels

### Cloudflare Tunnel Configuration
All public hostnames route via in-cluster `traefik.kube-system.svc.cluster.local:80`, except `flux-webhook.yuandrk.net` which targets `webhook-receiver.flux-system.svc.cluster.local:80`. See `apps/*/base/ingress.yaml` for per-service Traefik routing.

### Tunnel Management
- **Tunnel ID**: `4a6abf9a-d178-4a56-9586-a3d77907c5f1`
- **Configuration**: Terraform managed in `terraform/live/homelab/cloudflare/main.tf`
- **Deployment**: 2-replica `cloudflared` HelmRelease in the `networking` namespace (see `infrastructure/networking/cloudflared/`)

---

## 📝 Management Commands

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

---

## 🔮 Future Enhancements

### Planned Network Improvements
- **Network Policies**: Implement K3s NetworkPolicies for pod isolation
- **Service Mesh**: Consider Istio or Linkerd for advanced traffic management
- **Monitoring**: Deploy network monitoring (Prometheus + Grafana)
- **Firewall**: Implement UFW rules for additional security

### K3s Network Expansion
- **Ingress Classes**: Multiple ingress controllers for different services
- **External DNS**: Automate DNS record management
- **Load Balancing**: MetalLB for better service exposure
- **IPv6**: Enable IPv6 support for future-proofing

---

## 🧠 **Prompt Context (LLM)**
This homelab runs a **3-node K3s cluster** (1 master + 2 workers) with a **dual networking strategy**: high-speed direct LAN (10.10.0.0/24) for internal cluster communication and Wi-Fi fallback (192.168.1.0/24) for internet access.

**Key Network Features:**
- **Host DNS** via systemd-resolved → 1.1.1.1/8.8.8.8 (no host-level forwarder; CoreDNS handles cluster DNS independently)
- **K3s cluster networking** via Flannel CNI (pods: 10.42.0.0/16, services: 10.43.0.0/16)
- **Traefik ingress** handling ports 80/443 for K3s workloads
- **PostgreSQL database** on k3s-worker3 (native installation, not K3s-managed)
- **Cloudflare tunnels** for secure external access to select services

**Performance characteristics:** Gigabit speeds between workers (0.4ms latency), Wi-Fi speeds for master communication (6-9ms), sufficient internet access (14-19 Mbps) for external dependencies.

The network architecture supports both host-native services (PostgreSQL on worker3) and K3s workloads with external access via secure tunnels.
