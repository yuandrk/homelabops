---
created: 2025-07-27
tags:
  - ai
  - aws
  - terraform
---
# Terraform Homelab Infrastructure

This repository contains Terraform code for managing homelab infrastructure, specifically Cloudflare DNS and Tunnel resources.

## Repository Structure

```
terraform/
├── bootstrap/              # S3 backend + DynamoDB state management
├── cloudflare/             # Cloudflare DNS and Tunnel management
├── fluxcd/                 # Kubernetes Flux CD (not actively used)
└── modules/
    └── tunnel/             # Reusable Cloudflare Tunnel module
```

## Components
### 1. Bootstrap Stack (`bootstrap/`)
Manages Terraform remote state infrastructure:
- **S3 Bucket**: `terraform-state-homelab-yuandrk` (eu-west-2)
- **DynamoDB Table**: `terraform-homelab-lock` for state locking
- **Features**: Versioning, encryption (AES256), lifecycle policies (90-day retention)

### 2. Cloudflare Stack (`cloudflare/`)

Manages DNS and tunnel resources for the `yuandrk.net` domain:
- Uses existing Cloudflare Tunnel: `homeserver` (ID: `4a6abf9a-d178-4a56-9586-a3d77907c5f1`)
- Creates DNS CNAME records pointing to tunnel endpoints
- Configures tunnel ingress rules for service routing
### 3. Tunnel Module (`modules/tunnel/`)
A reusable module for managing Cloudflare Tunnels with the following resources:
#### Resources Created:
- `cloudflare_dns_record`: Creates CNAME record pointing to tunnel
- `cloudflare_zero_trust_tunnel_cloudflared_config`: Configures tunnel routing rules
- `data.cloudflare_zero_trust_tunnel_cloudflared_token`: Retrieves tunnel token for cloudflared daemon
#### Module Inputs:

```hcl
variable "account_id"          { type = string }  # Cloudflare Account ID
variable "zone_id"             { type = string }  # DNS Zone ID
variable "existing_tunnel_id"  { type = string }  # Tunnel ID to use
variable "hostname"            { type = string }  # Public hostname (e.g., pihole.yuandrk.net)
variable "service"             { type = string }  # Backend service URL (e.g., http://127.0.0.1:8081)
```
#### Module Outputs:

```hcl
output "tunnel_id"     { value = local.tunnel_id }                    # Tunnel ID
output "tunnel_cname"  { value = "${local.tunnel_id}.cfargotunnel.com" } # CNAME target
output "hostname"      { value = var.hostname }                      # Public hostname
output "tunnel_token"  { value = "..." sensitive = true }            # Token for cloudflared
```
## Current Configuration

### Services via Cloudflare Tunnels

| Service | Public Hostname | Backend Service | Status | Notes |
|---------|----------------|-----------------|--------|---------|
| **Pi-hole** | `pihole.yuandrk.net` | `http://127.0.0.1:8081` | ✅ Active | Port changed from 80→8081 due to K3s Traefik |
| **Budget App** | `budget.yuandrk.net` | K3s service | ✅ Active | Routed via K3s ingress |
| **Open-WebUI** | `chat.yuandrk.net` | `http://k3s-master:80` | ✅ Active | LLM interface via Traefik ingress, amd64 node affinity |

### Tunnel Configuration
- **Tunnel ID**: `4a6abf9a-d178-4a56-9586-a3d77907c5f1` (existing, imported)
- **Tunnel Name**: `homeserver`
- **DNS Records**: CNAME pointing to `{tunnel_id}.cfargotunnel.com`
- **Management**: Terraform-managed configuration
- **Deployment**: Cloudflared systemd service on k3s-master
## Usage
### Prerequisites
1. Cloudflare API Token with permissions:
    - `Zone:DNS:Edit`
    - `Zone:Zone:Read`
    - `Cloudflare Tunnel:Edit`
2. Terraform >= 1.8.0
3. Configured `terraform.tfvars` file
### Deployment Steps
1. **Initialize and apply bootstrap** (one-time):
    ```bash
    cd terraform/bootstrap/
    terraform init
    terraform apply
    ```
2. **Deploy Cloudflare resources**:
    ```bash
    cd terraform/cloudflare/
    terraform init
    terraform plan
    terraform apply
    ```
3. **Get tunnel token** for cloudflared daemon:
    ```bash
    terraform output -raw tunnel_token
    ```

### Resource Import (if needed)

```bash
# Import existing DNS record
terraform import module.pihole_tunnel.cloudflare_dns_record.this <zone_id>/<dns_record_id>

# Import existing tunnel config
terraform import module.pihole_tunnel.cloudflare_zero_trust_tunnel_cloudflared_config.this <tunnel_id>
```

## Provider Versions

- **Cloudflare Provider**: `>= 5.3.0, < 6.0`
- **AWS Provider**: `~> 6.0` (for bootstrap)
- **Terraform**: `>= 1.8.0, < 2.0`

## Terraform State

- **Backend**: S3 bucket with DynamoDB locking
- **State Files**:
    - `global/bootstrap.tfstate` - Bootstrap infrastructure
    - `cloudflare/terraform.tfstate` - Cloudflare resources

## Integration with K3s

### Port Conflict Resolution
- **Issue**: K3s Traefik LoadBalancer intercepts port 80/443 traffic
- **Solution**: Pi-hole web interface moved from port 80 → 8081
- **Terraform Update**: Backend service URL updated to `http://127.0.0.1:8081`
- **Verification**: `curl -I https://pihole.yuandrk.net` returns HTTP 403 (Pi-hole auth page)

### Current Architecture
- **K3s Master**: Runs both Traefik (ports 80/443) and Pi-hole (port 8081)
- **Cloudflare Tunnels**: Route external traffic to appropriate services
- **Service Separation**: K3s workloads use Traefik, host services use direct tunnels

---

## Notes

- The tunnel module currently uses an existing tunnel (`homeserver`) rather than creating new ones
- Tunnel configurations cannot be destroyed via Terraform and must be manually deleted from Cloudflare Dashboard if needed
- The DNS record was imported from existing infrastructure to maintain continuity
- **Port 8081**: Pi-hole web interface changed due to K3s integration
- Future enhancements could include creating new tunnels programmatically

## Future Enhancements

### Terraform Improvements
1. **Multiple Services**: Extend module to support multiple hostnames per tunnel
2. **New Tunnels**: Add capability to create new tunnels via Terraform
3. **Access Policies**: Add Cloudflare Access rules for authentication
4. **Monitoring**: Integrate with monitoring solutions for tunnel health checks

### K3s Integration
1. **Ingress Integration**: Direct K3s ingress to Cloudflare tunnels
2. **Service Discovery**: Automate tunnel creation for K3s services
3. **Certificate Management**: Integrate with cert-manager for TLS
4. **External DNS**: Automate DNS record creation for K3s services
