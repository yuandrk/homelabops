# 🏠 Home Lab – Snapshot  

## 1. Topology
| Role | Hostname | CPU Arch | vCPUs | RAM | Primary LAN IP |
|------|----------|----------|-------|-----|----------------|
| **Control-plane** | `k3s-master` | x86-64 | 4 thr | 15 GiB | 10.10.0.1 |
| **Worker #1** | `k3s-worker1` | ARM64 | 4 core | 3.7 GiB | 10.10.0.2 |
| **Worker #2** | `k3s-worker2` | ARM64 | 4 core | 3.7 GiB | 10.10.0.4 |

All nodes run **Ubuntu 24.04 LTS (kernel 6.8)**
## 2. Node Summaries

<details><summary><b>k3s-master</b></summary>

| Item | Value |
|------|-------|
| CPU | Intel i3-7100U @ 2.4 GHz (4 threads) |
| Memory | 15 GiB (≈10 % used) + 4 GiB swap (0 % used) |
| Storage | 931 GiB NVMe (6 % used) |
| Key Services | **Pi-hole DNS** (port 53) • K3s server |
| Open Ports | 80/443 (reverse-proxy), 53 (DNS), 22 (SSH) |
| Security | *UFW = off* • *Fail2Ban = off* |
</details>
<details><summary><b>k3s-worker1</b></summary>

| Item | Value |
|------|-------|
| CPU | 4 × Cortex-A72 |
| Memory | 3.7 GiB (≈9 % used) |
| Storage | 954 GiB USB-SSD (1 % used) |
| Services | |
| Open Ports | 22 (SSH), 53 (systemd-resolved) |
| Security | *UFW = off* |
</details>
<details><summary><b>k3s-worker2</b></summary>

| Item | Value |
|------|-------|
| CPU | 4 × Cortex-A72 |
| Memory | 3.7 GiB (≈9 % used) |
| Storage | 15 GiB eMMC (23 % used) |
| Services | |
| Open Ports | 22 (SSH), 53 (systemd-resolved) |
| Security | *UFW = off* |
| Uptime | 55 min |
</details>

---

## 3. Resource Snapshot
| Metric         | Master           | Worker1         | Worker2        |
| -------------- | ---------------- | --------------- | -------------- |
| CPU Load (1 m) | 0.11             | 0.25            | 0.00           |
| RAM Used       | 1.6 GiB          | 341 MiB         | 332 MiB        |
| Disk Used      | 53 GiB / 914 GiB | 3 GiB / 939 GiB | 3 GiB / 15 GiB |
