# 🤖 Homelab Infrastructure Inventory

> **Generated**: 2025-07-29 18:49:27
> **Purpose**: Comprehensive system state for AI analysis and GitOps planning
> **Format**: Optimized for LLM parsing with structured data sections

## 📊 Quick Stats

| Metric | Value |
|--------|-------|
| Total Nodes | 3 |
| Kubernetes Available | false |
| Inventory Version | 2.0 |

## 🎯 AI Context Summary

This inventory provides a complete snapshot of a homelab infrastructure consisting of:
- 1 x86-64 master node (Intel NUC) running K3s control plane and Pi-hole DNS
- 2 ARM64 worker nodes (Raspberry Pi 4) for workloads
- Mixed architecture cluster requiring multi-arch container images
- Network: 10.10.0.0/24 (wired) + 192.168.1.0/24 (WiFi for internet)

---

## 🖥️ Node Inventory

### 📦 k3s-master

#### System Profile
```yaml
hostname: k3s-master
kernel: 6.8.0-64-generic
os_version: Ubuntu 24.04.2 LTS
architecture: x86_64
uptime_days: 10
last_boot: N/A last_boot:          system boot  2025-07-19 14:14
```

#### Hardware Resources
```yaml
cpu:
  model: Intel(R) Core(TM) i3-7100U CPU @ 2.40GHz
  cores: 4
  architecture: x86_64
  load_average: 0.02, 0.01, 0.00
memory:
  total: 15Gi
  used: 1.7Gi
  available: 13Gi
  swap: 4.0Gi
storage:
  - /dev/mapper/ubuntu--vg-ubuntu--lv  914G  151G  725G  18% /
  - /dev/nvme0n1p2                     2.0G  193M  1.6G  11% /boot
  - /dev/nvme0n1p1                     1.1G  6.2M  1.1G   1% /boot/efi
```

#### Network Configuration
```yaml
interfaces:
  - name: lo
    ipv4: 127.0.0.1/8
  - name: enp0s31f6
    ipv4: 10.10.0.1/24
  - name: wlp2s0
    ipv4: 192.168.1.223/24
  - name: br-684542576ba7
    ipv4: 172.20.0.1/16
  - name: docker0
    ipv4: 172.17.0.1/16
  - name: br-92aecd2c1f9c
    ipv4: 172.18.0.1/16
  - name: br-b3a872c6a61d
    ipv4: 172.19.0.1/16
    ipv4: 172.21.0.1/16
dns_servers:
  - 10.10.0.1
  - 1.1.1.1
  - fe80
  - 192.168.1.1
  - 2a02
listening_ports:
  - 53
  - 80
  - 443
  - 2222
  - 5006
  - 5678
  - 8080
  - 8096
  - 8191
  - 9469
  - 9999
```

#### Active Services
```yaml
systemd_services:
  - cloudflared.service
  - pihole-FTL.service
  - snap.docker.dockerd.service

docker_containers:
- name: actual_server
    image: actualbudget/actual-server:25.7.0
    status: Up 9 days
    ports: 0.0.0.0:5006->5006/tcp, [::]:5006->5006/tcp
- name: n8n
    image: n8nio/n8n:1.99.1
    status: Up 10 days
    ports: 0.0.0.0:5678->5678/tcp, [::]:5678->5678/tcp
- name: practical_wilbur
    image: ghcr.io/yuandrk/csv-processor:latest
    status: Up 9 days
    ports: 0.0.0.0:9999->5000/tcp, [::]:9999->5000/tcp
- name: qbittorrent
    image: ghcr.io/hotio/qbittorrent
    status: Up 10 days
    ports: 0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
- name: jellyfin
    image: lscr.io/linuxserver/jellyfin:latest
    status: Up 10 days
    ports: 0.0.0.0:8096->8096/tcp, [::]:8096->8096/tcp, 8920/tcp
- name: flaresolverr
    image: ghcr.io/flaresolverr/flaresolverr:latest
    status: Up 10 days
    ports: 0.0.0.0:8191->8191/tcp, [::]:8191->8191/tcp, 8192/tcp

k3s_containers:
```

#### Security Configuration
```yaml
ssh:
  port: 
  password_auth: 
firewall:
  ufw_status: 
  iptables_rules: 0
0
updates:
  pending: 10
  reboot_required: no
```

#### Performance Metrics (Live)
```yaml
cpu_usage_percent: 7
memory_usage_percent: 10
disk_io:
  - device: loop2
    read_mb_s: 0.00
    write_mb_s: 1225          0          0
  - device: loop3
    read_mb_s: 0.00
    write_mb_s: 75071          0          0
  - device: loop4
    read_mb_s: 0.00
    write_mb_s: 491          0          0
  - device: loop5
    read_mb_s: 0.00
    write_mb_s: 7402          0          0
  - device: loop6
    read_mb_s: 0.00
    write_mb_s: 28180          0          0
  - device: loop7
    read_mb_s: 0.00
    write_mb_s: 1226          0          0
  - device: loop8
    read_mb_s: 0.00
network_traffic:
  - interface: lo
    rx_bytes: bytes
  - interface: enp0s31f6
    rx_bytes: bytes
  - interface: wlp2s0
    rx_bytes: bytes
  - interface: br-684542576ba7
    rx_bytes: bytes
  - interface: docker0
    rx_bytes: bytes
  - interface: br-92aecd2c1f9c
    rx_bytes: bytes
  - interface: br-b3a872c6a61d
    rx_bytes: bytes
  - interface: veth38ab8f1
    rx_bytes: bytes
```

---

### 📦 k3s-worker1

#### System Profile
```yaml
hostname: k3s-worker1
kernel: 6.8.0-1030-raspi
os_version: Ubuntu 24.04.2 LTS
architecture: aarch64
uptime_days: 10
last_boot: N/A last_boot:          system boot  2025-06-04 13:24
```

#### Hardware Resources
```yaml
cpu:
  model: Cortex-A72
  cores: 4
  architecture: aarch64
  load_average: 0.26, 0.22, 0.13
memory:
  total: 3.7Gi
  used: 701Mi
  available: 3.0Gi
  swap: 0B
storage:
  - /dev/sda2       939G  4.2G  897G   1% /
  - /dev/sda1       505M  182M  323M  36% /boot/firmware
```

#### Network Configuration
```yaml
interfaces:
  - name: lo
    ipv4: 127.0.0.1/8
  - name: eth0
    ipv4: 10.10.0.2/24
  - name: wlan0
    ipv4: 192.168.1.137/24
  - name: br-3334ef6aa242
    ipv4: 172.18.0.1/16
  - name: docker0
    ipv4: 172.17.0.1/16
dns_servers:
  - 10.10.0.1
  - 1.1.1.1
  - 10.10.0.1
  - 1.1.1.1
listening_ports:
  - 53
  - 2222
  - 5432
  - 5959
```

#### Active Services
```yaml
systemd_services:
  - containerd.service
  - docker.service

docker_containers:
  - none

k3s_containers:
```

#### Security Configuration
```yaml
ssh:
  port: 
  password_auth: 
firewall:
  ufw_status: 
  iptables_rules: 0
0
updates:
  pending: 10
  reboot_required: yes
```

#### Performance Metrics (Live)
```yaml
cpu_usage_percent: 8
memory_usage_percent: 18
disk_io:
  - device: sda
    read_mb_s: 0.00
    write_mb_s: 1338786    8727286          0
  - device: Device
    read_mb_s: kB_dscd/s
    write_mb_s: kB_read    kB_wrtn    kB_dscd
  - device: loop0
    read_mb_s: 0.00
    write_mb_s: 0          0          0
  - device: loop1
    read_mb_s: 0.00
    write_mb_s: 0          0          0
  - device: loop2
    read_mb_s: 0.00
    write_mb_s: 0          0          0
  - device: sda
    read_mb_s: 0.00
    write_mb_s: 0          0          0
network_traffic:
  - interface: lo
    rx_bytes: bytes
  - interface: eth0
    rx_bytes: bytes
  - interface: wlan0
    rx_bytes: bytes
  - interface: br-3334ef6aa242
    rx_bytes: bytes
  - interface: docker0
    rx_bytes: bytes
```

---

### 📦 k3s-worker2

#### System Profile
```yaml
hostname: k3s-worker2
kernel: 6.8.0-1029-raspi
os_version: Ubuntu 24.04.2 LTS
architecture: aarch64
uptime_days: 30
last_boot: N/A last_boot:          system boot  2025-06-04 13:24
```

#### Hardware Resources
```yaml
cpu:
  model: Cortex-A72
  cores: 4
  architecture: aarch64
  load_average: 0.29, 0.12, 0.04
memory:
  total: 3.7Gi
  used: 443Mi
  available: 3.3Gi
  swap: 0B
storage:
  - /dev/mmcblk0p2   15G  2.5G   11G  19% /
  - /dev/mmcblk0p1  505M  182M  323M  36% /boot/firmware
```

#### Network Configuration
```yaml
interfaces:
  - name: lo
    ipv4: 127.0.0.1/8
  - name: eth0
    ipv4: 10.10.0.4/24
  - name: wlan0
    ipv4: 192.168.1.70/24
dns_servers:
  - 10.10.0.1
  - 1.1.1.1
  - 10.10.0.1
  - 1.1.1.1
listening_ports:
  - 53
  - 2222
```

#### Active Services
```yaml
systemd_services:

docker_containers:
  - none

k3s_containers:
```

#### Security Configuration
```yaml
ssh:
  port: 
  password_auth: 
firewall:
  ufw_status: 
  iptables_rules: 0
0
updates:
  pending: 5
  reboot_required: yes
```

#### Performance Metrics (Live)
```yaml
cpu_usage_percent: 5
memory_usage_percent: 11
disk_io:
  - device: loop3
    read_mb_s: 0.00
    write_mb_s: 10          0          0
  - device: mmcblk0
    read_mb_s: 8.95
    write_mb_s: 755102   18785892   23421071
  - device: Device
    read_mb_s: kB_dscd/s
    write_mb_s: kB_read    kB_wrtn    kB_dscd
  - device: loop0
    read_mb_s: 0.00
    write_mb_s: 0          0          0
  - device: loop1
    read_mb_s: 0.00
    write_mb_s: 0          0          0
  - device: loop2
    read_mb_s: 0.00
    write_mb_s: 0          0          0
  - device: loop3
    read_mb_s: 0.00
network_traffic:
  - interface: lo
    rx_bytes: bytes
  - interface: eth0
    rx_bytes: bytes
  - interface: wlan0
    rx_bytes: bytes
```

---

## 🔄 GitOps Readiness Assessment

```yaml
gitops_tools:
  flux_installed: yes
  helm_installed: yes

automation_gaps:

manual_processes:
  - PostgreSQL running in Docker Compose on k3s-worker1
  - Pi-hole running bare metal on k3s-master
  - No automated certificate management
  - No centralized logging
  - No automated backups
```
---
*Generated by inventory.sh v2.0 on 2025-07-29 18:49:27*
*Node SSH access via ~/.ssh/config using hostnames*
