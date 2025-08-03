# FluxCD GitOps Setup

Complete guide to FluxCD v2.6.0 deployment and configuration for the homelab K3s cluster.

## Overview

FluxCD is deployed via Terraform and provides GitOps continuous deployment capabilities. It monitors the Git repository and automatically applies changes to the cluster.

## Architecture

### Components Deployed
- **helm-controller**: Manages Helm releases
- **kustomize-controller**: Handles Kustomize resources
- **source-controller**: Manages Git repository sources
- **notification-controller**: Handles webhooks and notifications
- **image-reflector-controller**: Scans container registries
- **image-automation-controller**: Automates image updates

### Repository Structure
```
clusters/prod/
├── flux-system/          # FluxCD system components
│   ├── gotk-components.yaml
│   ├── gotk-sync.yaml
│   └── kustomization.yaml
└── production/           # Production environment configs
    ├── apps.yaml
    ├── infrastructure.yaml
    └── monitoring.yaml
```

## Deployment

### Terraform Configuration
FluxCD is deployed using Terraform with the following configuration:

```bash
cd terraform/fluxcd
terraform init
terraform plan
terraform apply
```

### Key Resources Created
- **TLS Private Key**: ECDSA P256 key for Git authentication
- **GitHub Deploy Key**: Automatic repository access configuration
- **FluxCD Bootstrap**: Complete FluxCD installation

### Variables
- `github_token`: GitHub Personal Access Token
- `github_owner`: Repository owner (yuandrk)
- `repository_name`: Repository name (homelabops)
- `kubeconfig_path`: Path to cluster kubeconfig
- `flux_version`: FluxCD version (v2.6.0)

## Configuration

### Git Repository
- **URL**: `ssh://git@github.com/yuandrk/homelabops.git`
- **Branch**: `main`
- **Path**: `clusters/prod/`
- **Authentication**: SSH deploy key (ECDSA P256)

### Synchronization
- **Interval**: 1 minute polling
- **Components**: Full FluxCD stack with image automation
- **Namespace**: `flux-system`

### External Access
- **Webhook URL**: `https://flux-webhook.yuandrk.net`
- **Service**: NodePort 30080 on k3s-worker1
- **Purpose**: GitHub webhook notifications for instant updates

## Status Verification

### Check FluxCD System
```bash
# Check all FluxCD pods
kubectl --kubeconfig=terraform/kube/kubeconfig get pods -n flux-system

# Check Git repository status
kubectl --kubeconfig=terraform/kube/kubeconfig get gitrepository -n flux-system

# Check kustomizations
kubectl --kubeconfig=terraform/kube/kubeconfig get kustomization -n flux-system
```

### Expected Output
```
NAME          URL                                           AGE    READY   STATUS
flux-system   ssh://git@github.com/yuandrk/homelabops.git   6m7s   True    stored artifact for revision 'main@sha1:...'
```

## Workflow

### Adding Applications
1. Create HelmRelease in `apps/` directory
2. Commit and push to main branch
3. FluxCD automatically detects and deploys changes

### Infrastructure Changes
1. Add configurations to `infrastructure/` directory
2. Update kustomization files as needed
3. FluxCD reconciles changes automatically

### Manual Reconciliation
```bash
# Force reconciliation (if needed)
kubectl --kubeconfig=terraform/kube/kubeconfig \
  annotate --overwrite gitrepository flux-system \
  -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

## Security

### SSH Key Management
- Private key stored in Terraform state (sensitive)
- Public key added as GitHub deploy key automatically
- Read-write access for repository updates

### Access Control
- FluxCD runs in dedicated `flux-system` namespace
- RBAC configured for cluster-admin permissions
- Network policies enabled

## Troubleshooting

### Common Issues

#### Git Authentication Failures
```bash
# Check SSH key configuration
kubectl --kubeconfig=terraform/kube/kubeconfig \
  get secret flux-system -n flux-system -o yaml
```

#### Repository Sync Issues
```bash
# Check source controller logs
kubectl --kubeconfig=terraform/kube/kubeconfig \
  logs -n flux-system deployment/source-controller
```

#### Webhook Connectivity
- Webhook endpoint: `https://flux-webhook.yuandrk.net`
- Backend service: NodePort 30080 on k3s-worker1
- Current status: 502 (hostname resolution issue)

### Manual Fixes
```bash
# Delete and recreate GitRepository
kubectl --kubeconfig=terraform/kube/kubeconfig \
  delete gitrepository flux-system -n flux-system

# Restart FluxCD controllers
kubectl --kubeconfig=terraform/kube/kubeconfig \
  rollout restart deployment -n flux-system
```

## Integration

### Cloudflare Tunnel
FluxCD webhook is exposed via Cloudflare tunnel:
- **Service**: `http://k3s-worker1:30080`
- **Hostname**: `flux-webhook.yuandrk.net`
- **Purpose**: GitHub webhook notifications

### GitHub Integration
- Deploy key automatically created
- Repository access configured
- Webhook endpoint available for instant updates

## Maintenance

### Updates
FluxCD version is managed via Terraform variable:
```hcl
variable "flux_version" {
  default = "v2.6.0"
}
```

### Backup
- Terraform state contains SSH keys and configuration
- GitOps configuration stored in Git repository
- Cluster manifests in `clusters/prod/` directory

## Current Status (August 2025)

### Active Applications
- **open-webui**: LLM interface with Ollama integration (3 pods running)
  - Status: HelmRelease shows failed due to timeout, but application is healthy
  - Services: open-webui, open-webui-ollama, open-webui-pipelines

### Cleaned Up Applications
- **Removed**: todoist, cert-manager, github, actualbudget, n8n, headlamp
- **Reason**: Unused applications causing resource consumption and maintenance overhead
- **Method**: Complete directory removal to prevent kustomization parsing errors

### System Health
- ✅ **FluxCD Controllers**: All 6 controllers healthy
- ✅ **Kustomizations**: apps, infra-configs, flux-system all working
- ✅ **Git Sync**: Repository monitoring and reconciliation functional
- ⚠️ **Webhook**: External access configured but experiencing hostname resolution issues

## Next Steps

1. **Add Applications**: Create HelmReleases in `apps/` directory
2. **Configure Infrastructure**: Add ingress, certificates in `infrastructure/`
3. **Setup Monitoring**: Deploy observability stack via FluxCD
4. **Fix Webhook**: Resolve hostname resolution for instant updates

## Troubleshooting

For common issues and solutions, see [FluxCD Troubleshooting Guide](./FluxCD-Troubleshooting.md).

## References

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [GitOps Toolkit](https://toolkit.fluxcd.io/)
- [Terraform FluxCD Provider](https://registry.terraform.io/providers/fluxcd/flux/latest/docs)
