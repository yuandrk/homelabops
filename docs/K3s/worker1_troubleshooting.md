# Worker1 Troubleshooting Report

## Issue Summary
k3s-worker1 (10.10.0.2) is experiencing SSH connection issues preventing remote management.

## Symptoms
- ✅ **Network connectivity**: Ping successful (0.7ms latency)
- ✅ **SSH port open**: Port 2222 shows as open in nmap
- ❌ **SSH handshake failure**: Connection reset during key exchange
- ❌ **Ansible connection failure**: "Input/output error"

## Root Cause Analysis
The SSH daemon is running and accepting connections but failing during the authentication handshake. This typically indicates:

1. **System resource exhaustion** (memory/CPU)
2. **SSH daemon corruption** 
3. **Filesystem issues** affecting SSH keys/config
4. **Previous k3s processes** still consuming resources

## Recommended Solutions

### Immediate Action Required
1. **Power cycle the device** (unplug/replug power)
2. **Check physical status** (LEDs, display if available)
3. **Console access** if available (HDMI/serial)

### After Restart
1. **Test SSH connectivity**:
   ```bash
   ssh k3s-worker1 "uptime && free -h && df -h"
   ```

2. **Check system resources**:
   ```bash
   ssh k3s-worker1 "top -bn1 | head -20"
   ```

3. **Check for stuck k3s processes**:
   ```bash
   ssh k3s-worker1 "ps aux | grep k3s"
   ```

4. **Clean any remaining k3s installation**:
   ```bash
   ssh k3s-worker1 "sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || echo 'Already clean'"
   ```

### Deploy with Ansible
Once SSH is working:
```bash
# Test connectivity
ansible -i ansible/inventory/hosts.ini k3s-worker1 -m ping

# Deploy k3s (our refactored role will handle everything)
ANSIBLE_BECOME_PASS=yuandrk200 ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/cluster_bootstrap.yaml --limit k3s-worker1
```

## Current Cluster Status
- ✅ **k3s-master**: Ready (control-plane)
- ✅ **k3s-worker2**: Ready (joined successfully)  
- ❌ **k3s-worker1**: SSH inaccessible (needs restart)

## Next Steps
After power cycling worker1:
1. Confirm SSH access is restored
2. Deploy k3s using our refactored role
3. Verify 3-node cluster is fully operational
