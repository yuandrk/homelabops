# K3s Cluster Network Performance Analysis

**Date**: August 2, 2025  
**Cluster**: 3-node K3s cluster (1 master + 2 workers)  
**Analysis Tools**: ping, iperf3, curl

## Network Topology

### Node Details
- **k3s-master**: 192.168.1.223 (x86-64, Wi-Fi connected)
- **k3s-worker1**: 192.168.1.137 / 10.10.0.2 (ARM64 RPi, dual network)
- **k3s-worker2**: 192.168.1.70 / 10.10.0.4 (ARM64 RPi, dual network)

### Network Segments
- **Wi-Fi Network**: 192.168.1.0/24 (BT router)
- **Direct LAN**: 10.10.0.0/24 (wired connection between workers)

## Performance Results

### Inter-Node Latency (ping)
```
Master → Worker1:  6.3ms avg  (Wi-Fi to Wi-Fi)
Master → Worker2:  9.2ms avg  (Wi-Fi to Wi-Fi)
Worker1 → Worker2: 0.4ms avg  (Direct LAN) ⚡
```

### Inter-Node Bandwidth (iperf3)
```
Master → Worker1:   60.6 Mbps  (Wi-Fi limitation)
Worker1 ↔ Worker2:  932 Mbps   (Gigabit LAN) ⚡
```

### Internet Download Speeds (curl)
```
k3s-master:  18.7 Mbps (2.34 MB/s)
k3s-worker1: 17.2 Mbps (2.15 MB/s)
k3s-worker2: 14.4 Mbps (1.80 MB/s)
```

## Analysis Summary

### Performance Tiers
1. **🥇 Worker-to-Worker**: 932 Mbps, 0.4ms - Excellent for pod communication
2. **🥈 Master-to-Workers**: 60 Mbps, 6-9ms - Good for control plane traffic  
3. **🥉 Internet Access**: 14-19 Mbps - Typical home broadband

### Key Findings

#### Excellent Discovery
- **Worker nodes have direct LAN connectivity** (10.10.0.x network)
- **Near-zero latency** between workers (0.4ms)
- **Gigabit speeds** between workers (932 Mbps)
- **Master connects via Wi-Fi** to both worker nodes

#### K3s Implications
- **Pod Networking**: Excellent performance for workloads on worker nodes
- **Control Plane**: Adequate Wi-Fi performance for master communication
- **External Services**: Good speeds for image pulls and external APIs
- **Storage**: Fast inter-worker communication benefits distributed storage

#### Optimization Recommendations
- **Workload Placement**: Deploy high-communication workloads on worker nodes
- **Storage Strategy**: Use worker-to-worker replication for performance
- **Network Policies**: Leverage fast worker-to-worker communication
- **Master Role**: Keep master focused on control plane functions

## Technical Details

### Test Commands Used
```bash
# Latency testing
ping -c 10 <target-host>

# Bandwidth testing  
iperf3 -s -D  # server
iperf3 -c <target> -t 5  # client

# Internet speed testing
curl -o /dev/null -s -w 'Download speed: %{speed_download} bytes/sec' \
  --max-time 10 http://speedtest.tele2.net/10MB.zip
```

### Network Configuration
- **K3s Pod Network**: 10.42.0.0/16 (Flannel CNI)
- **K3s Service Network**: 10.43.0.0/16 (ClusterIP)
- **Host Network**: Mixed Wi-Fi (192.168.1.x) and LAN (10.10.0.x)

## Conclusion

This K3s cluster has an **optimal network configuration** for high-performance workloads:
- Direct gigabit connectivity between worker nodes
- Adequate Wi-Fi connectivity for control plane operations  
- Consistent internet access across all nodes

The dual-network setup (Wi-Fi + direct LAN) provides both external connectivity and high-speed internal communication, making it excellent for distributed applications and storage solutions.
