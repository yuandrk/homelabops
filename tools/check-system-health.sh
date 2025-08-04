#!/bin/bash
# System Health Check Script for HomeLab Infrastructure
# Checks K3s cluster, FluxCD, and application status

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set kubeconfig path
KUBECONFIG_PATH="/Users/yuandrk/Nextcloud/github/homelabops/terraform/kube/kubeconfig"
export KUBECONFIG="$KUBECONFIG_PATH"

# Function to print colored output
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo -e "${BLUE}"
echo "🔍 HomeLab System Health Check"
echo "=============================="
echo -e "${NC}"
echo "Timestamp: $(date)"
echo "Kubeconfig: $KUBECONFIG_PATH"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_PATH" ]; then
    print_error "Kubeconfig not found at $KUBECONFIG_PATH"
    exit 1
fi

print_header "K3s Cluster Status"

# Check cluster connectivity
if kubectl cluster-info >/dev/null 2>&1; then
    print_success "Cluster connectivity established"
else
    print_error "Cannot connect to K3s cluster"
    exit 1
fi

# Check node status
print_info "Node Status:"
kubectl get nodes --no-headers | while read node status role age version; do
    if [ "$status" = "Ready" ]; then
        echo -e "  ${GREEN}✅${NC} $node ($role) - $status"
    else
        echo -e "  ${RED}❌${NC} $node ($role) - $status"
    fi
done

print_header "FluxCD Installation Status"

# Check FluxCD namespace
if kubectl get namespace flux-system >/dev/null 2>&1; then
    print_success "FluxCD namespace exists"
else
    print_error "FluxCD namespace not found"
    exit 1
fi

# Check FluxCD controllers
print_info "FluxCD Controllers:"
kubectl get pods -n flux-system --no-headers | while read pod ready status restarts age; do
    if [ "$status" = "Running" ] && [ "$ready" = "1/1" ]; then
        echo -e "  ${GREEN}✅${NC} $pod"
    else
        echo -e "  ${RED}❌${NC} $pod - $status ($ready)"
    fi
done

print_header "Git Repository Synchronization"

# Check GitRepository status
repo_status=$(kubectl get gitrepository flux-system -n flux-system --no-headers 2>/dev/null | awk '{print $4}' || echo "NotFound")
if [ "$repo_status" = "True" ]; then
    print_success "Git repository synchronized"
    latest_commit=$(kubectl get gitrepository flux-system -n flux-system -o jsonpath='{.status.artifact.revision}' 2>/dev/null)
    print_info "Latest revision: $latest_commit"
    
    # Check last update time
    last_update=$(kubectl get gitrepository flux-system -n flux-system -o jsonpath='{.status.artifact.lastUpdateTime}' 2>/dev/null)
    print_info "Last update: $last_update"
else
    print_error "Git repository sync failed - Status: $repo_status"
fi

print_header "Kustomization Status"

# Check all kustomizations
kustomizations=$(kubectl get kustomization -n flux-system --no-headers 2>/dev/null || echo "")
if [ -n "$kustomizations" ]; then
    echo "$kustomizations" | while read name age ready status; do
        if [ "$ready" = "True" ]; then
            echo -e "  ${GREEN}✅${NC} $name - Applied"
        else
            echo -e "  ${RED}❌${NC} $name - $status"
        fi
    done
else
    print_warning "No kustomizations found"
fi

print_header "Application Status"

# Check HelmReleases
helmreleases=$(kubectl get helmrelease -A --no-headers 2>/dev/null || echo "")
if [ -n "$helmreleases" ]; then
    print_info "Helm Releases:"
    echo "$helmreleases" | while read ns name age ready status; do
        if [ "$ready" = "True" ]; then
            echo -e "  ${GREEN}✅${NC} $ns/$name"
        else
            echo -e "  ${RED}❌${NC} $ns/$name - Failed"
        fi
    done
else
    print_warning "No Helm releases found"
fi

# Check application pods
print_info "Application Pods:"
app_pods=$(kubectl get pods -n apps --no-headers 2>/dev/null || echo "")
if [ -n "$app_pods" ]; then
    echo "$app_pods" | while read pod ready status restarts age; do
        if [ "$status" = "Running" ] && [[ "$ready" == "1/1" ]]; then
            echo -e "  ${GREEN}✅${NC} $pod"
        else
            echo -e "  ${RED}❌${NC} $pod - $status ($ready)"
        fi
    done
else
    print_warning "No application pods found"
fi

print_header "Ingress and External Access"

# Check ingress
ingresses=$(kubectl get ingress -A --no-headers 2>/dev/null || echo "")
if [ -n "$ingresses" ]; then
    print_info "Ingress Resources:"
    echo "$ingresses" | while read ns name class hosts address ports age; do
        echo -e "  ${GREEN}✅${NC} $hosts ($ns/$name)"
    done
else
    print_warning "No ingress resources found"
fi

print_header "External Service Health"

# Check external services
services=(
    "https://chat.yuandrk.net"
    "https://pihole.yuandrk.net"
    "https://budget.yuandrk.net"
    "https://flux-webhook.yuandrk.net"
)

print_info "External Service Accessibility:"
for service in "${services[@]}"; do
    if command -v curl >/dev/null 2>&1; then
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$service" 2>/dev/null || echo "000")
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
            echo -e "  ${GREEN}✅${NC} $service (HTTP $http_code)"
        elif [ "$http_code" = "403" ]; then
            echo -e "  ${YELLOW}⚠️${NC}  $service (HTTP $http_code - Auth required)"
        else
            echo -e "  ${RED}❌${NC} $service (HTTP $http_code)"
        fi
    else
        echo -e "  ${YELLOW}⚠️${NC}  $service (curl not available)"
    fi
done

print_header "Resource Usage"

# Check node resource usage if metrics are available
if kubectl top nodes >/dev/null 2>&1; then
    print_info "Node Resource Usage:"
    kubectl top nodes | tail -n +2 | while read node cpu_cores cpu_percent memory memory_percent; do
        echo -e "  ${BLUE}📊${NC} $node - CPU: $cpu_percent, Memory: $memory_percent"
    done
else
    print_warning "Node metrics not available (metrics-server might not be running)"
fi

# Check pod resource usage in flux-system
if kubectl top pods -n flux-system >/dev/null 2>&1; then
    print_info "FluxCD Resource Usage:"
    kubectl top pods -n flux-system --no-headers | while read pod cpu memory; do
        echo -e "  ${BLUE}📊${NC} $pod - CPU: $cpu, Memory: $memory"
    done
fi

print_header "Summary"

# Overall health assessment
failed_components=0

# Count failures (this is a simplified check)
if ! kubectl get pods -n flux-system --no-headers | grep -q "1/1.*Running"; then
    failed_components=$((failed_components + 1))
fi

if [ "$repo_status" != "True" ]; then
    failed_components=$((failed_components + 1))
fi

if [ $failed_components -eq 0 ]; then
    print_success "System is healthy! All components operational."
    echo -e "\n${GREEN}🎉 HomeLab infrastructure is running smoothly!${NC}"
else
    print_error "Found $failed_components failed components. Check details above."
    echo -e "\n${RED}⚠️  System requires attention. Review failed components above.${NC}"
fi

echo -e "\n${BLUE}Health check completed at $(date)${NC}"

# Exit with error code if issues found
exit $failed_components
