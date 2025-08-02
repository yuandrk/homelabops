# 📡 Homelab Network Layout (June 2025)

### 🧾 Overview
-   **Main LAN**: `10.10.0.0/24` (wired via unmanaged switch)
-   **Wi‑Fi fallback**: `192.168.1.0/24` (via BT router)
-   **No NAT** — all outbound traffic uses Wi‑Fi
-   **Wired LAN** used for local services, Docker, SSH, file transfer
---
### 🖥️ Devices & IPs

| Device       | Hostname      | Interface | IP address    | Notes              |
| ------------ | ------------- | --------- | ------------- | ------------------ |
| Master PC    | `k3s-master`  | enp0s31f6 | 10.10.0.1/24  | Main Docker host   |
|              |               | wlp2s0    | 192.168.1.223 | Wi‑Fi for Internet |
| Raspberry Pi | `k3s-worker1` | eth0      | 10.10.0.2/24  | DB stack           |
|              |               | wlan0     | 192.168.1.139 | Wi‑Fi fallback     |
| Raspberry Pi | `k3s-worker2` | eth0      | 10.10.0.4/24  | General use node   |
|              |               | wlan0     | 192.168.1.69  | Wi‑Fi fallback     |


---
### 🧱 Topology (ASCII)

```txt
┌─────────────┐
                     │   BT Wi‑Fi  │
                     │  (Router)   │
                     └──────┬──────┘
                            │
                  Wi‑Fi (192.168.1.x)
            ┌───────────────┼─────────────────┐
            │               │                 │
        [k3s-master]   [k3s-worker1]  [k3s-worker2]
       wlp2s0            wlan0              wlan0
   192.168.1.223     192.168.1.139      192.168.1.69

──────────── Wired LAN (10.10.0.0/24 via Unmanaged Switch) ────────────

 [main] enp0s31f6   [slave] eth0   [slavemini] eth0    [MacBook]
   10.10.0.1         10.10.0.2         10.10.0.4         10.10.0.10
             └────────────┬─────────────┬──────────────┘
                          │   Switch    │
                          └─────────────┘
```
