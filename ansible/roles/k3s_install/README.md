# K3s Install Role

Idempotent Ansible role for installing and managing K3s clusters with automatic token delegation and configuration change detection.

## Features

- ✅ **Idempotent installations** - safe to run multiple times
- ✅ **Automatic token delegation** - workers fetch tokens from master automatically
- ✅ **Configuration change detection** - automatic uninstall/reinstall when config changes
- ✅ **Safe partial runs** - `--limit workers` works correctly
- ✅ **Optional hostname management** - manages `/etc/hosts` entries when enabled
- ✅ **Systemd integration** - proper daemon-reload and environment files
- ✅ **Network separation** - internal cluster networks don't conflict with host LAN

## Variables

### Core Configuration
```yaml
k3s_install_channel: stable                    # K3s release channel
k3s_install_exact_version: ""                  # Override channel with specific version
k3s_install_api_endpoint: "{{ master_ip }}"    # API endpoint for workers (auto-detected)
```

### Network Configuration
```yaml
# These internal networks operate at different layers and don't conflict with host LAN
k3s_install_cluster_cidr: "10.42.0.0/16"      # Pod network (CNI overlay)
k3s_install_service_cidr: "10.43.0.0/16"      # Service network (kube-proxy)
```

### Optional Features
```yaml
k3s_install_manage_hosts: false                # Manage /etc/hosts entries
k3s_install_server_args: []                    # Additional server arguments
k3s_install_agent_args: []                     # Additional agent arguments  
k3s_install_tls_sans: ["{{ ansible_host }}"]   # TLS Subject Alternative Names
```

## Network Architecture

The role configures three separate network layers:

1. **Host Network (10.10.0.0/24)**: Physical node communication
   - Used for: SSH, node-to-node traffic, API server access
   - Configured on: Physical/VM network interfaces

2. **Pod Network (10.42.0.0/16)**: Container-to-container communication
   - Used for: Pod-to-pod traffic via CNI
   - Configured by: K3s CNI plugin (Flannel)

3. **Service Network (10.43.0.0/16)**: Service discovery and load balancing
   - Used for: ClusterIP services, DNS resolution
   - Configured by: kube-proxy

These networks operate at different layers and don't conflict - host routing handles 10.10.0.0/24 while CNI/kube-proxy handle the internal ranges.

## Usage

### Basic Cluster
```yaml
- hosts: all
  roles:
    - k3s_install
```

### With Hostname Management
```yaml  
- hosts: all
  vars:
    k3s_install_manage_hosts: true
  roles:
    - k3s_install
```

### Custom Configuration
```yaml
- hosts: all
  vars:
    k3s_install_exact_version: "v1.28.5+k3s1"
    k3s_install_server_args: 
      - "--disable=traefik"
      - "--disable=servicelb"
    k3s_install_agent_args:
      - "--node-label=type=worker"
  roles:
    - k3s_install
```

## Inventory Requirements

```ini
[masters]
k3s-master ansible_host=10.10.0.1

[workers]  
k3s-worker1 ansible_host=10.10.0.2
k3s-worker2 ansible_host=10.10.0.4
```

## Safe Operations

### Partial Runs
```bash
# This now works correctly - workers will fetch token from master
ansible-playbook playbook.yaml --limit workers
```

### Configuration Changes
The role automatically detects configuration changes and triggers clean uninstall/reinstall:
- Version changes
- Argument changes  
- Network CIDR changes
- TLS SAN changes

### Manual Cleanup
```bash
# Clean uninstall if needed
ANSIBLE_BECOME_PASS=password ansible workers -m shell -a "/usr/local/bin/k3s-agent-uninstall.sh"
ANSIBLE_BECOME_PASS=password ansible masters -m shell -a "/usr/local/bin/k3s-uninstall.sh"
```

## Files Created

- `/etc/rancher/k3s/config.checksum` - Configuration change tracking
- `/etc/rancher/k3s/k3s.env` - Environment file for workers (if using templates)
- `/etc/hosts` - Hostname entries (if `k3s_install_manage_hosts: true`)

## Troubleshooting

### Worker Connection Issues
1. Check API endpoint: `k3s_install_api_endpoint` should resolve from workers
2. Verify token: Role automatically fetches from master
3. Check firewall: Port 6443 must be accessible

### Configuration Not Applied
1. Check checksum: `/etc/rancher/k3s/config.checksum`
2. Force reinstall: Delete checksum file and re-run
3. Manual cleanup: Use uninstall scripts if needed

## Dependencies

- Ansible 2.9+
- sudo access on target nodes
- Internet access for K3s installation script
- Port 6443 accessible between nodes
