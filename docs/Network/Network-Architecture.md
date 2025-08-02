# 🌐 Homelab Network Architecture (August 2025)

**Status**: ✅ K3s cluster operational with dual networking setup  
**Last Updated**: August 2, 2025  
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
| **Master** | `k3s-master` | 10.10.0.1/24 | 192.168.1.223 | Control Plane | Pi-hole DNS, K3s Server, Traefik |
| **Worker 1** | `k3s-worker1` | 10.10.0.2/24 | 192.168.1.137 | Worker Node | PostgreSQL (Docker), K3s Agent |
| **Worker 2** | `k3s-worker2` | 10.10.0.4/24 | 192.168.1.70 | Worker Node | K3s Agent |

### Hardware Specs
- **k3s-master**: Intel i3-7100U, 15 GiB RAM, 931 GiB NVMe (x86-64)
- **k3s-worker1**: ARM64 RPi 4, 3.7 GiB RAM, 954 GiB USB-SSD 
- **k3s-worker2**: ARM64 RPi 4, 3.7 GiB RAM, 15 GiB eMMC

---

## 📡 Network Topology

```txt
┌─────────────────┐
│   BT Wi-Fi      │ 🌐 Internet Access
│   (Router)      │ 192.168.1.0/24
└────────┬────────┘
         │
    Wi-Fi Cloud ☁️
    ┌────┼────┐
    │    │    │
[k3s-master] [worker1] [worker2]
192.168.1.223 .137     .70
    │    │    │
    │    │    │ 
════════════════════════════════════
    │ 10.10.0.0/24 LAN │ ⚡ Gigabit
════════════════════════════════════
    │    │    │
  .1/24 .2/24 .4/24
[k3s-master] [worker1] [worker2]
    │    │    │
    └────┴────┘
   [Unmanaged Switch]

K3s Pod Networks (Flannel):
├─ Master Pods:  10.42.0.x/24
├─ Worker1 Pods: 10.42.2.x/24  
└─ Worker2 Pods: 10.42.1.x/24

K3s Services: 10.43.0.0/16
```

---

## 🚦 Port Mapping & Services

### k3s-master (10.10.0.1)
| Service | Port | Protocol | Access | Notes |
|---------|------|----------|--------|-------|
| **Pi-hole DNS** | 53 | UDP | LAN-wide | Host-level DNS server |
| **Pi-hole Web** | 8081 | HTTP | Local only | Moved from port 80 due to Traefik |
| **Traefik** | 80, 443 | HTTP/HTTPS | LAN + External | K3s ingress controller |
| **K3s API** | 6443 | HTTPS | Internal | Kubernetes API server |
| **SSH** | 2222 | TCP | LAN | Hardened SSH port |

### k3s-worker1 (10.10.0.2)
| Service | Port | Protocol | Access | Notes |
|---------|------|----------|--------|-------|
| **PostgreSQL** | 5432 | TCP | LAN | Docker container (n8n database) |
| **SSH** | 2222 | TCP | LAN | Hardened SSH port |
| **systemd-resolved** | 53 | UDP | Local | Local DNS stub |

### k3s-worker2 (10.10.0.4)
| Service | Port | Protocol | Access | Notes |
|---------|------|----------|--------|-------|
| **SSH** | 2222 | TCP | LAN | Hardened SSH port |
| **systemd-resolved** | 53 | UDP | Local | Local DNS stub |

---

## 🌍 DNS Architecture

### Dual DNS Setup
```
Applications/Browsers
        ↓
   Pi-hole (10.10.0.1:53)
   ├─ Host DNS resolution
   ├─ Ad/tracker blocking  
   ├─ Custom domain routing
   └─ Upstream: Cloudflare (1.1.1.1)

K3s Pods
        ↓
   CoreDNS (10.42.0.3:53)
   ├─ Service discovery
   ├─ Internal .cluster.local
   └─ Upstream: Host DNS
```

### DNS Configuration

#### systemd-resolved Override (All Nodes)
```ini
# /etc/systemd/resolved.conf.d/pihole.conf
[Resolve]
DNS=10.10.0.1 1.1.1.1
Domains=~.
ResolveUnicastSingleLabel=yes
FallbackDNS=
```

#### Pi-hole Configuration
- **Service**: Pi-hole FTL on k3s-master
- **Web Interface**: `http://k3s-master:8081/admin`
- **External Access**: `https://pihole.yuandrk.net` (Cloudflare tunnel)
- **Port Change**: Moved from 80 → 8081 due to K3s Traefik conflict

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

### Network Conflicts Resolved
- **Pi-hole Port Conflict**: Web interface moved from port 80 → 8081
- **Root Cause**: K3s Traefik LoadBalancer intercepts port 80/443 traffic
- **Solution**: Updated Pi-hole config in `/etc/pihole/pihole.toml`
- **Cloudflare Update**: Terraform config updated to route to port 8081

### K3s Networking Features
- **CNI**: Flannel VXLAN for pod networking
- **Service Mesh**: ClusterIP services via kube-proxy
- **Load Balancer**: Traefik for ingress traffic
- **API Access**: Uses `k3s_install_api_endpoint: 10.10.0.1:6443` for reliability

---

## 🛡️ Security Configuration

### Network Security
- **SSH Hardening**: All nodes use port 2222 with key-based auth
- **DNS Security**: Pi-hole blocks ads/trackers at network level
- **Firewall**: Currently disabled (UFW=off) - LAN-only access
- **Tunnel Security**: Cloudflare tunnels for secure external access

### Access Control
- **Internal Only**: Most services only accessible via LAN
- **External Access**: Limited to specific services via Cloudflare tunnels
- **Service Isolation**: K3s network policies can be implemented as needed

---

## 🚀 External Services & Tunnels

### Cloudflare Tunnel Configuration
| Service | Internal Endpoint | External Domain | Status |
|---------|------------------|-----------------|---------|
| **Pi-hole** | `http://127.0.0.1:8081` | `pihole.yuandrk.net` | ✅ Active |
| **Budget App** | K3s service | `budget.yuandrk.net` | ✅ Active |

### Tunnel Management
- **Tunnel ID**: `4a6abf9a-d178-4a56-9586-a3d77907c5f1`
- **Configuration**: Terraform managed in `terraform/cloudflare/main.tf`
- **Deployment**: Cloudflared systemd service on k3s-master

---

## 📝 Management Commands

### Network Diagnostics
```bash
# Test internal connectivity
ping k3s-worker1              # Should resolve via Pi-hole
resolvectl query k3s-master   # DNS resolution test

# Check K3s network
kubectl get nodes -o wide     # Node IPs and status
kubectl get pods -o wide -A   # Pod distribution across nodes

# Performance testing
iperf3 -c k3s-worker1 -t 5    # Bandwidth test
ping -c 10 k3s-worker2        # Latency test
```

### DNS Management
```bash
# Pi-hole management
systemctl status pihole-FTL   # Service status
pihole status                 # Pi-hole status
pihole restartdns            # Restart DNS

# systemd-resolved
systemctl restart systemd-resolved
resolvectl flush-caches      # Clear DNS cache
```

---

## 🔮 Future Enhancements

### Planned Network Improvements
- **Network Policies**: Implement K3s NetworkPolicies for pod isolation
- **Service Mesh**: Consider Istio or Linkerd for advanced traffic management
- **Monitoring**: Deploy network monitoring (Prometheus + Grafana)
- **Backup DNS**: Add secondary Pi-hole for redundancy
- **Firewall**: Implement UFW rules for additional security

### K3s Network Expansion
- **Ingress Classes**: Multiple ingress controllers for different services
- **External DNS**: Automate DNS record management
- **Load Balancing**: MetalLB for better service exposure
- **IPv6**: Enable IPv6 support for future-proofing

---

## 🧠 **Prompt Context (LLM)**
This homelab runs a **3-node K3s cluster** with a **dual networking strategy**: high-speed direct LAN (10.10.0.0/24) for internal cluster communication and Wi-Fi fallback (192.168.1.0/24) for internet access.

**Key Network Features:**
- **Pi-hole DNS** on k3s-master (port 8081 web, port 53 DNS) with ad-blocking
- **K3s cluster networking** via Flannel CNI (pods: 10.42.0.0/16, services: 10.43.0.0/16)
- **Traefik ingress** handling ports 80/443 for K3s workloads
- **PostgreSQL database** on k3s-worker1 (Docker, not K3s-managed)
- **Cloudflare tunnels** for secure external access to select services

**Performance characteristics:** Gigabit speeds between workers (0.4ms latency), Wi-Fi speeds for master communication (6-9ms), sufficient internet access (14-19 Mbps) for external dependencies.

The network architecture supports both traditional services (Pi-hole, PostgreSQL) and modern K3s workloads with external access via secure tunnels.
