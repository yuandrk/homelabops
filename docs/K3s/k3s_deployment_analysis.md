# K3s Deployment Analysis - Issues and Solutions

## What Happened

### Successful Parts
1. ✅ **Master Installation**: k3s server installed successfully on k3s-master (10.10.0.1)
   - Service is running and healthy
   - API server accessible on port 6443
   - Traefik ingress controller deployed

### Failed Parts
2. ❌ **Worker Node Connection**: Both worker nodes (k3s-worker1, k3s-worker2) failing to join cluster

## Root Cause Analysis

### Issue 1: Hostname vs IP Address Resolution
**Problem**: Workers trying to connect to `k3s-master:6443` but hostname not resolving
```
export K3S_URL="https://k3s-master:6443"  # ❌ Hostname not in DNS/hosts
```

**Evidence**: Worker logs show connection failures:
```
Failed to validate connection to cluster at https://k3s-master:6443
```

**Fix Applied**: Changed to use IP address:
```
export K3S_URL="https://{{ hostvars[groups['masters'][0]]['ansible_host'] }}:6443"  # ✅ Uses 10.10.0.1
```

### Issue 2: Ansible Playbook Flow Problems
**Problem**: When re-running playbook with `--limit workers`, token gathering task skipped
- Token collection happens on master node only
- Workers need master token but master tasks don't run when limited to workers
- Results in undefined variable error

### Issue 3: Service State Management
**Problem**: k3s-agent services were running with old/wrong configuration
- Services started with hostname-based URL
- Restart attempts timed out
- Needed clean stop → reconfigure → start cycle

## Technical Issues Identified

### 1. Network Configuration
- ✅ Host network: 10.10.0.0/24 properly configured
- ✅ SSH connectivity working (ansible ping successful)
- ✅ K3s internal networks (10.42.0.0/16, 10.43.0.0/16) don't conflict
- ❌ Hostname resolution between nodes not configured

### 2. Ansible Role Logic
- ✅ Idempotency checks work for fresh installs
- ❌ Token delegation logic breaks when running partial playbook
- ❌ Service restart/reconfiguration not handled properly

### 3. K3s Configuration
- ✅ TLS SANs configured correctly for master
- ✅ Cluster and service CIDRs set appropriately
- ❌ Worker connection string incorrect

## Solutions Required

### Immediate Fixes
1. **Clean Worker State**:
   ```bash
   # Stop services
   systemctl stop k3s-agent
   # Remove k3s installation
   /usr/local/bin/k3s-agent-uninstall.sh
   # Clean up any remaining files
   ```

2. **Fix Hostname Resolution** (Choose one):
   - Option A: Add entries to `/etc/hosts` on all nodes
   - Option B: Use IP addresses consistently (current approach)
   - Option C: Set up proper DNS resolution

3. **Improve Ansible Role**:
   - Better error handling for partial runs
   - Force worker reinstall when configuration changes
   - Add cleanup tasks for failed installs

### Long-term Improvements
1. **Add health checks** after installation
2. **Implement proper cleanup/uninstall** tasks
3. **Add DNS/hostname resolution** setup in role
4. **Better token management** (perhaps store in ansible facts)

## Current State
- **Master**: ✅ Running and healthy
- **Worker1**: ❌ k3s-agent installed but misconfigured
- **Worker2**: ❌ k3s-agent installed but misconfigured
- **Kubeconfig**: ❌ Not extracted yet (playbook didn't complete)

## Recommended Next Steps
1. Clean up worker nodes completely
2. Fix hostname resolution or ensure IP-based URLs work
3. Re-run deployment with clean state
4. Verify cluster status before proceeding to commit

## Lessons Learned
- Always test network connectivity and name resolution first
- Ansible playbook partial runs can break inter-node dependencies
- K3s workers are sensitive to connection URL changes
- Service restarts during configuration changes need careful handling
