# Headlamp Kubernetes Dashboard

This document provides comprehensive information about the Headlamp Kubernetes dashboard deployment and access management.

## Overview

Headlamp is a modern Kubernetes dashboard that provides a user-friendly interface for managing Kubernetes clusters. It's deployed using Helm via FluxCD and secured with RBAC and SOPS-encrypted tokens.

## Deployment Architecture

- **Namespace**: `kube-system`
- **Deployment Method**: Helm via FluxCD
- **Chart**: `headlamp/headlamp` (version >=0.21.0)
- **External Access**: `https://headlamp.yuandrk.net` (via Cloudflare Tunnel)
- **Authentication**: ServiceAccount token-based

## Access Information

### URL
```
https://headlamp.yuandrk.net
```

### Authentication Token
The authentication token is stored as a SOPS-encrypted secret in the repository:
- **Secret Name**: `headlamp-token`
- **Secret Namespace**: `kube-system`
- **File**: `infrastructure/configs/headlamp/token.enc.yaml`

### Retrieving the Token

#### From SOPS-encrypted secret:
```bash
sops -d infrastructure/configs/headlamp/token.enc.yaml | grep "token:" | awk '{print $2}'
```

#### From Kubernetes secret (if deployed):
```bash
kubectl get secret headlamp-token -n kube-system -o jsonpath="{.data.token}" | base64 --decode
```

#### Generate a new token:
```bash
kubectl create token headlamp-admin -n kube-system --duration=8760h
```

## ServiceAccount Configuration

### ServiceAccount Details
- **Name**: `headlamp-admin`
- **Namespace**: `kube-system`
- **ClusterRole**: `cluster-admin`
- **Permissions**: Full cluster access

### Verification Commands
```bash
# Check ServiceAccount exists
kubectl get serviceaccount headlamp-admin -n kube-system

# Verify ClusterRoleBinding
kubectl get clusterrolebinding headlamp-admin

# Test permissions
kubectl auth can-i list pods --as=system:serviceaccount:kube-system:headlamp-admin
```

## Token Management

### Current Token Information
- **Created**: 2025-08-09
- **Expires**: 2026-08-09 (1 year validity)
- **Service Account**: `headlamp-admin`
- **Scope**: Full cluster access via `cluster-admin` role

### Token Rotation

When the token expires or needs rotation:

1. **Generate new token**:
   ```bash
   kubectl create token headlamp-admin -n kube-system --duration=8760h
   ```

2. **Update encrypted secret**:
   ```bash
   # Create temporary file with new token
   cat > /tmp/headlamp-token.yaml << EOF
   apiVersion: v1
   kind: Secret
   metadata:
     name: headlamp-token
     namespace: kube-system
   type: Opaque
   stringData:
     token: YOUR_NEW_TOKEN_HERE
     serviceaccount: headlamp-admin
     namespace: kube-system
     expires: "YYYY-MM-DDTHH:MM:SSZ"
   EOF
   
   # Encrypt and replace
   cp /tmp/headlamp-token.yaml infrastructure/configs/headlamp/token.enc.yaml
   sops -e -i infrastructure/configs/headlamp/token.enc.yaml
   
   # Commit changes
   git add infrastructure/configs/headlamp/token.enc.yaml
   git commit -m "feat: rotate Headlamp authentication token"
   git push origin main
   ```

## Troubleshooting

### Common Issues

#### 1. Token Expired
**Symptoms**: Authentication failed, token rejected
**Solution**: Generate new token following the rotation procedure above

#### 2. Insufficient Permissions
**Symptoms**: Can't view/modify resources
**Solution**: Verify ClusterRoleBinding exists and ServiceAccount has cluster-admin role

#### 3. Ingress Not Working
**Symptoms**: Can't access https://headlamp.yuandrk.net
**Solution**: Check ingress configuration and Traefik status

### Diagnostic Commands
```bash
# Check Headlamp pod status
kubectl get pods -n kube-system | grep headlamp

# Check Headlamp service
kubectl get svc -n kube-system | grep headlamp

# Check ingress
kubectl get ingress -n kube-system | grep headlamp

# Check HelmRelease status
kubectl get helmreleases -n flux-system headlamp

# View Headlamp logs
kubectl logs -n kube-system deployment/kube-system-headlamp
```

## Security Considerations

### Token Security
- Tokens are encrypted at rest using SOPS with age encryption
- Tokens have limited validity (1 year) for security rotation
- Access is restricted to cluster-admin level permissions

### Network Security
- External access only via Cloudflare Tunnel (HTTPS)
- Internal access through Traefik ingress controller
- No direct node port or LoadBalancer exposure

### RBAC
- Uses dedicated ServiceAccount with explicit permissions
- Follows principle of least privilege (cluster-admin for dashboard functionality)
- Permissions can be reduced if needed for specific use cases

## Configuration Files

### Helm Configuration
- **Repository**: `infrastructure/configs/headlamp/repository.yaml`
- **Release**: `infrastructure/configs/headlamp/release.yaml`
- **RBAC**: `infrastructure/configs/headlamp/rbac.yaml`
- **Token**: `infrastructure/configs/headlamp/token.enc.yaml` (SOPS encrypted)
- **Kustomization**: `infrastructure/configs/headlamp/kustomization.yaml`

### FluxCD Management
Headlamp is managed by the `infra-configs` Kustomization:
```bash
kubectl get kustomizations -n flux-system infra-configs
```

## Usage Tips

### Navigation
- **Workloads**: View and manage pods, deployments, services
- **Config & Storage**: ConfigMaps, secrets, PVCs
- **Network**: Ingress, network policies
- **RBAC**: ServiceAccounts, roles, bindings
- **Events**: Cluster-wide events and logs

### Features
- Real-time cluster monitoring
- Resource editing via YAML
- Log viewing and streaming
- Event timeline
- Plugin support (configured via Helm values)

---

**Note**: This setup provides full cluster access. For production environments with multiple users, consider implementing more granular RBAC policies and user-specific tokens.