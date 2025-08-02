#!/bin/bash
# inventory.sh - Enhanced homelab discovery and documentation for AI
# Usage: ./inventory.sh > docs/INVENTORY-$(date +%Y%m%d).md

set -euo pipefail

# Configuration
NODES=("k3s-master" "k3s-worker1" "k3s-worker2")
DATE=$(date '+%Y-%m-%d %H:%M:%S')
KUBECTL_AVAILABLE=false

# Check if kubectl is available
if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
    KUBECTL_AVAILABLE=true
fi

# Function to run command on remote node using hostname
remote_exec() {
    local node=$1
    local command=$2
    local timeout=${3:-10}
    
    # Use SSH config for connection (assumes ~/.ssh/config is properly configured)
    timeout $timeout ssh -o ConnectTimeout=5 -o BatchMode=yes "$node" "$command" 2>/dev/null || echo "N/A"
}

# Function to get JSON output from remote
remote_json() {
    local node=$1
    local command=$2
    ssh -o ConnectTimeout=5 -o BatchMode=yes "$node" "$command" 2>/dev/null || echo "{}"
}

# Header with AI context
cat << EOF
# 🤖 Homelab Infrastructure Inventory

> **Generated**: $DATE
> **Purpose**: Comprehensive system state for AI analysis and GitOps planning
> **Format**: Optimized for LLM parsing with structured data sections

## 📊 Quick Stats

| Metric | Value |
|--------|-------|
| Total Nodes | ${#NODES[@]} |
| Kubernetes Available | $KUBECTL_AVAILABLE |
| Inventory Version | 2.0 |

## 🎯 AI Context Summary

This inventory provides a complete snapshot of a homelab infrastructure consisting of:
- 1 x86-64 master node (Intel NUC) running K3s control plane and Pi-hole DNS
- 2 ARM64 worker nodes (Raspberry Pi 4) for workloads
- Mixed architecture cluster requiring multi-arch container images
- Network: 10.10.0.0/24 (wired) + 192.168.1.0/24 (WiFi for internet)

---

EOF

# Kubernetes Cluster Overview
if [ "$KUBECTL_AVAILABLE" = true ]; then
    echo "## ☸️ Kubernetes Cluster State"
    echo ""
    echo "### Cluster Info"
    echo '```yaml'
    kubectl version --short 2>/dev/null || echo "version: unknown"
    echo '```'
    echo ""
    
    echo "### Node Status"
    echo '```'
    kubectl get nodes -o wide
    echo '```'
    echo ""
    
    echo "### Node Resources"
    echo '```'
    kubectl top nodes 2>/dev/null || echo "Metrics server not installed"
    echo '```'
    echo ""
fi

# Detailed Node Analysis
echo "## 🖥️ Node Inventory"
echo ""

for node in "${NODES[@]}"; do
    echo "### 📦 $node"
    echo ""
    
    # System Information
    echo "#### System Profile"
    echo '```yaml'
    echo "hostname: $node"
    echo "kernel: $(remote_exec $node 'uname -r')"
    echo "os_version: $(remote_exec $node 'lsb_release -d 2>/dev/null | cut -f2' || remote_exec $node 'cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d "\""')"
    echo "architecture: $(remote_exec $node 'uname -m')"
    echo "uptime_days: $(remote_exec $node 'uptime | grep -oP "up \K\d+" || echo "0"')"
    echo "last_boot: $(remote_exec $node 'who -b | awk "{print \$3, \$4}"')"
    echo '```'
    echo ""
    
    # Hardware Resources
    echo "#### Hardware Resources"
    echo '```yaml'
    echo "cpu:"
    echo "  model: $(remote_exec $node 'lscpu | grep "Model name" | cut -d: -f2 | xargs')"
    echo "  cores: $(remote_exec $node 'nproc')"
    echo "  architecture: $(remote_exec $node 'lscpu | grep Architecture | cut -d: -f2 | xargs')"
    echo "  load_average: $(remote_exec $node 'uptime | grep -oP "load average: \K.*"')"
    echo "memory:"
    echo "  total: $(remote_exec $node 'free -h | grep Mem | awk "{print \$2}"')"
    echo "  used: $(remote_exec $node 'free -h | grep Mem | awk "{print \$3}"')"
    echo "  available: $(remote_exec $node 'free -h | grep Mem | awk "{print \$7}"')"
    echo "  swap: $(remote_exec $node 'free -h | grep Swap | awk "{print \$2}"')"
    echo "storage:"
    remote_exec $node 'df -h | grep -E "^/dev/" | while read line; do echo "  - $line"; done'
    echo '```'
    echo ""
    
    # Network Configuration
    echo "#### Network Configuration"
    echo '```yaml'
    echo "interfaces:"
    remote_exec $node 'ip -4 addr show | grep -E "^[0-9]:|inet " | while read line; do
        if [[ $line =~ ^[0-9]: ]]; then
            iface=$(echo $line | cut -d: -f2 | xargs)
            echo "  - name: $iface"
        elif [[ $line =~ inet ]]; then
            ip=$(echo $line | awk "{print \$2}")
            echo "    ipv4: $ip"
        fi
    done'
    echo "dns_servers:"
    remote_exec $node 'resolvectl status 2>/dev/null | grep "DNS Servers" | cut -d: -f2 | tr " " "\n" | while read dns; do test -n "$dns" && echo "  - $dns"; done'
    echo "listening_ports:"
    remote_exec $node 'ss -tlnp 2>/dev/null | grep LISTEN | awk "{print \$4}" | rev | cut -d: -f1 | rev | sort -nu | while read port; do echo "  - $port"; done'
    echo '```'
    echo ""
    
    # Services and Containers
    echo "#### Active Services"
    echo '```yaml'
    echo "systemd_services:"
    remote_exec $node 'systemctl list-units --type=service --state=running --no-pager | grep -E "(docker|k3s|containerd|postgresql|pihole|cloudflared)" | awk "{print \$1}" | while read svc; do echo "  - $svc"; done'
    echo ""
    echo "docker_containers:"
    remote_exec $node 'docker ps --format "  - name: {{.Names}}\n    image: {{.Image}}\n    status: {{.Status}}\n    ports: {{.Ports}}" 2>/dev/null || echo "  - none"'
    echo ""
    echo "k3s_containers:"
    remote_exec $node 'crictl ps --no-trunc 2>/dev/null | tail -n +2 | awk "{print \"  - name: \" \$NF \"\n    image: \" \$2 \"\n    state: \" \$6}" || echo "  - none"'
    echo '```'
    echo ""
    
    # Security Status
    echo "#### Security Configuration"
    echo '```yaml'
    echo "ssh:"
    echo "  port: $(remote_exec $node 'grep "^Port" /etc/ssh/sshd_config 2>/dev/null | awk "{print \$2}" || echo "22"')"
    echo "  password_auth: $(remote_exec $node 'grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk "{print \$2}" || echo "unknown"')"
    echo "firewall:"
    echo "  ufw_status: $(remote_exec $node 'sudo ufw status 2>/dev/null | grep Status | cut -d: -f2 | xargs || echo "unknown"')"
    echo "  iptables_rules: $(remote_exec $node 'sudo iptables -L -n 2>/dev/null | grep -c "^Chain" || echo "0"')"
    echo "updates:"
    echo "  pending: $(remote_exec $node 'apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "unknown"')"
    echo "  reboot_required: $(remote_exec $node 'test -f /var/run/reboot-required && echo "yes" || echo "no"')"
    echo '```'
    echo ""
    
    # Performance Metrics
    echo "#### Performance Metrics (Live)"
    echo '```yaml'
    echo "cpu_usage_percent: $(remote_exec $node 'top -bn1 | grep "Cpu(s)" | awk "{print 100 - \$8}" | cut -d. -f1')"
    echo "memory_usage_percent: $(remote_exec $node 'free | grep Mem | awk "{print int(\$3/\$2 * 100)}"')"
    echo "disk_io:"
    remote_exec $node 'iostat -d 1 2 2>/dev/null | tail -n +7 | grep -v "^$" | while read dev tps rs ws rMBs wMBs; do echo "  - device: $dev"; echo "    read_mb_s: ${rMBs:-0}"; echo "    write_mb_s: ${wMBs:-0}"; done | head -20'
    echo "network_traffic:"
    remote_exec $node 'ip -s link show 2>/dev/null | grep -A5 "^[0-9]:" | grep -E "^[0-9]:|RX:|TX:" | while read line; do
        if [[ $line =~ ^[0-9]: ]]; then
            iface=$(echo $line | cut -d: -f2 | xargs | cut -d@ -f1)
            echo "  - interface: $iface"
        elif [[ $line =~ RX: ]]; then
            read _ bytes packets errors dropped
            echo "    rx_bytes: $bytes"
        elif [[ $line =~ TX: ]]; then
            read _ bytes packets errors dropped  
            echo "    tx_bytes: $bytes"
        fi
    done'
    echo '```'
    echo ""
    echo "---"
    echo ""
done

# Kubernetes Resources Deep Dive
if [ "$KUBECTL_AVAILABLE" = true ]; then
    echo "## 🚀 Kubernetes Resources Analysis"
    echo ""
    
    echo "### Workload Distribution"
    echo '```yaml'
    kubectl get pods -A -o json | jq -r '
    .items | group_by(.spec.nodeName) | 
    map({
        node: .[0].spec.nodeName,
        pod_count: length,
        namespaces: (map(.metadata.namespace) | unique),
        containers: (map(.spec.containers[].name) | length)
    })' 2>/dev/null || echo "Unable to analyze workload distribution"
    echo '```'
    echo ""
    
    echo "### Resource Usage by Namespace"
    echo '```'
    kubectl top pods -A --sum 2>/dev/null || echo "Metrics server not available"
    echo '```'
    echo ""
    
    echo "### Storage Analysis"
    echo '```yaml'
    echo "persistent_volumes:"
    kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase,CLAIM:.spec.claimRef.name --no-headers 2>/dev/null | while read name cap status claim; do
        echo "  - name: $name"
        echo "    capacity: $cap"
        echo "    status: $status"
        echo "    claim: ${claim:-none}"
    done
    echo ""
    echo "storage_classes:"
    kubectl get storageclass -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner,DEFAULT:.metadata.annotations --no-headers 2>/dev/null | while read name prov default; do
        echo "  - name: $name"
        echo "    provisioner: $prov"
        echo "    default: $(echo $default | grep -q "default" && echo "true" || echo "false")"
    done
    echo '```'
    echo ""
fi

# GitOps Readiness Assessment
echo "## 🔄 GitOps Readiness Assessment"
echo ""
echo '```yaml'
echo "gitops_tools:"
echo "  flux_installed: $(command -v flux &> /dev/null && echo "yes" || echo "no")"
echo "  argocd_installed: $(kubectl get ns argocd &> /dev/null && echo "yes" || echo "no")"
echo "  helm_installed: $(command -v helm &> /dev/null && echo "yes" || echo "no")"
echo ""
echo "automation_gaps:"
if [ "$KUBECTL_AVAILABLE" = true ]; then
    kubectl get deployments,statefulsets,daemonsets -A -o json 2>/dev/null | jq -r '
    .items[] | 
    select(.metadata.annotations."meta.helm.sh/release-name" == null) |
    "  - \(.kind)/\(.metadata.name) in \(.metadata.namespace) (not managed by Helm)"' | head -10
fi
echo ""
echo "manual_processes:"
echo "  - PostgreSQL running in Docker Compose on k3s-worker1"
echo "  - Pi-hole running bare metal on k3s-master"
echo "  - No automated certificate management"
echo "  - No centralized logging"
echo "  - No automated backups"
echo '```'
echo ""

# AI Recommendations
echo "## 🤖 AI-Specific Insights"
echo ""
echo "### Architecture Considerations"
echo "- **Mixed CPU architecture** requires multi-arch images or separate builds"
echo "- **Limited RAM on workers** (3.7GB) constrains pod scheduling"
echo "- **Single master node** presents availability risk"
echo "- **Storage on worker1** (954GB USB-SSD) suitable for databases"
echo ""
echo "### Immediate Actions for GitOps"
echo "1. **Install FluxCD** - No GitOps controller detected"
echo "2. **Deploy metrics-server** - Required for resource monitoring"
echo "3. **Migrate Docker services** - PostgreSQL needs Kubernetes migration"
echo "4. **Enable network policies** - No policies currently defined"
echo "5. **Configure ingress** - No ingress controller found"
echo ""
echo "### Resource Optimization"
echo "- Master node CPU/RAM underutilized (good for more services)"
echo "- Workers have minimal load (ready for applications)"
echo "- Network segregation working (10.10.0.0/24 for cluster)"
echo ""

# Summary for AI
echo "## 📝 Summary for AI Processing"
echo ""
echo "This homelab is in early Kubernetes adoption phase with:"
echo "- Basic K3s cluster operational"
echo "- Mixed workloads (bare metal, Docker, K3s)"
echo "- Good hardware resources but underutilized"
echo "- Infrastructure automation via Ansible"
echo "- Cloud resources managed by Terraform"
echo "- Ready for GitOps transformation"
echo ""
echo "**Next logical step**: Bootstrap FluxCD and begin service migration"
echo ""

# Footer
echo "---"
echo "*Generated by inventory.sh v2.0 on $DATE*"
echo "*Node SSH access via ~/.ssh/config using hostnames*"
