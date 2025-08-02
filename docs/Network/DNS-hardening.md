# Homelab DNS & Network Hardening (June 2025)

## ✅ Scope & Tasks Completed
- **Pi‑hole deployed** on `k3s‑master` (10.10.0.1) and made authoritative DNS for the 10.10.0.0/24 LAN.
- **Static wired IPs** configured via Netplan on both Raspberry Pi nodes.
- **systemd‑resolved override** (`/etc/systemd/resolved.conf.d/pihole.conf`) installed on every node to:
  - Force Pi‑hole (10.10.0.1) as primary resolver.
  - Forward single‑label hostnames (`k3s-master`) to unicast DNS.
  - Keep Cloudflare (1.1.1.1) as secondary.
- **Hostnames aligned** → `k3s‑master`, `k3s‑worker1`, `k3s‑worker2` with matching `/etc/hosts` entries.
- Removed deprecated `gateway4` key; Wi‑Fi remains sole default route.
## 🎯 Benefits
| Area            | Benefit                                                                    |
| --------------- | -------------------------------------------------------------------------- |
| Name Resolution | Single‑label hostnames resolve everywhere via Pi‑hole; no mDNS flakiness   |
| Security        | Ad/tracker blocking; explicit firewall; sudo‑hostname mismatch fixed       |
| Reliability     | Static LAN IPs guarantee stable SSH & K3s node identity                    |
| Clean Config    | No deprecation warnings; configs live in predictable paths                 |

---
## 📄 Configuration Files

### 1  `/etc/systemd/resolved.conf.d/pihole.conf` — all nodes
```ini
[Resolve]
DNS=10.10.0.1 1.1.1.1
Domains=~.
ResolveUnicastSingleLabel=yes
FallbackDNS=
```

### 2  `/etc/hosts` additions
```text
# k3s‑master
127.0.1.1   k3s-master
# k3s‑worker1
127.0.1.1   k3s-worker1
# k3s‑worker2
127.0.1.1   k3s-worker2
```

### 3  Netplan — `k3s‑worker1` (10.10.0.2)
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses: [10.10.0.2/24]
      link-local: []                   # suppress 169.254.x.x
      nameservers:
        addresses: [10.10.0.1, 1.1.1.1]
        search: []                     # no suffixes
  wifis:
    wlan0:
      optional: true
      dhcp4: true
      dhcp4-overrides: { use-dns: false }
      dhcp6: no
      accept-ra: no
      access-points:
        "CommunityFibre10Gb_93FCE":
          auth:
            key-management: psk
            password: "8bc6898a7309d9419e55ec49f0253120a2dbcbea76512b86ff27a1d41daf4c9e"

```

### 4  Netplan — `k3s‑worker2` (10.10.0.4)
```yaml
network:
  version: 2
  renderer: networkd

  ethernets:
    eth0:
      addresses: [10.10.0.4/24]
      link-local: []                   # suppress 169.254.x.x
      nameservers:
        addresses: [10.10.0.1, 1.1.1.1]
        search: []                     # no suffixes

  wifis:
    wlan0:
      optional: true
      dhcp4: true
      dhcp4-overrides: { use-dns: false }
      dhcp6: no
      accept-ra: no
      access-points:
        "CommunityFibre10Gb_93FCE":
          auth:
            key-management: psk
            password: "[WiFi password hash]"
```


### Pi-hole 
### on k3s-worker{1..2} 

``` shell
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo cp /etc/systemd/resolved.conf.d/pihole.conf /etc/systemd/resolved.conf.d/pihole.conf.backup 2>/dev/null || true
```

``` shell 
sudo tee /etc/systemd/resolved.conf.d/pihole.conf >/dev/null <<'EOF'
[Resolve]
DNS=10.10.0.1 1.1.1.1
Domains=~.
ResolveUnicastSingleLabel=yes
FallbackDNS=
EOF
```

``` shell 
sudo systemctl restart systemd-resolved
sudo resolvectl flush-caches
```

Qiuck test: 
``` shell
resolvectl query k3s-master     # should return 10.10.0.1 and/or IPv6
ping -c2 k3s-master             # should resolve & reply
```
