# Terraform Infrastructure Guide

## Overview

This repository uses Terraform to manage homelab infrastructure with a focus on Cloudflare DNS/Tunnels and AWS backend state management. The infrastructure follows GitOps principles with automated CI/CD via GitHub Actions.

## Repository Structure

```
terraform/
├── live/homelab/              # Live environment (production)
│   ├── aws-bootstrap/         # S3 backend infrastructure (one-time setup)
│   ├── aws-oidc/              # GitHub OIDC provider & IAM role (one-time setup)
│   ├── cloudflare/            # Cloudflare DNS & Tunnels (actively managed)
│   └── fluxcd/                # FluxCD bootstrap (historical, not actively used)
└── modules/
    └── tunnel/                # Reusable Cloudflare Tunnel module
```

## Architecture

### 1. AWS Bootstrap Stack (`live/homelab/aws-bootstrap/`)

**Purpose**: One-time setup for Terraform remote state storage

**Resources**:
- **S3 Bucket**: `terraform-state-homelab-yuandrk` (eu-west-2)
  - Versioning enabled
  - Server-side encryption (AES256)
  - Lifecycle policy (90-day retention for old versions)
  - Public access blocked
- **No DynamoDB**: Uses S3 native locking (Terraform 1.13+)

**Backend Configuration**:
```hcl
# backend.hcl
bucket       = "terraform-state-homelab-yuandrk"
key          = "global/bootstrap.tfstate"
region       = "eu-west-2"
encrypt      = true
use_lockfile = true  # S3 native locking
```

### 2. AWS OIDC Stack (`live/homelab/aws-oidc/`)

**Purpose**: GitHub Actions authentication without long-lived credentials

**Resources**:
- **OIDC Provider**: `token.actions.githubusercontent.com`
  - Thumbprints: GitHub's official SSL certificates
  - Client ID: `sts.amazonaws.com`
- **IAM Role**: `GitHubActionsTerraformRole`
  - Trust policy: Scoped to `yuandrk/homelabops` repository
  - Permissions: S3 state bucket read/write/list access

**Trust Policy**:
```json
{
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": [
        "repo:yuandrk/homelabops:ref:refs/heads/main",
        "repo:yuandrk/homelabops:*"
      ]
    }
  }
}
```

### 3. Cloudflare Stack (`live/homelab/cloudflare/`)

**Purpose**: Manage DNS records and Cloudflare Tunnel configuration

**Resources**:
- DNS CNAME records (via `modules/tunnel`)
- Tunnel ingress configuration (`cloudflare_zero_trust_tunnel_cloudflared_config`)

**Current Services**:

| Service | Hostname | Backend | Notes |
|---------|----------|---------|-------|
| Pi-hole | `pihole.yuandrk.net` | `http://127.0.0.1:8081` | DNS + ad blocking |
| ActualBudget | `budget.yuandrk.net` | `http://k3s-master:80` | Financial management |
| n8n | `n8n.yuandrk.net` | `http://k3s-master:80` | Workflow automation |
| Flux Webhook | `flux-webhook.yuandrk.net` | `http://k3s-worker1:30080` | GitOps webhooks |
| Open-WebUI | `llm.yuandrk.net` | `http://k3s-master:80` | LLM interface |
| Grafana | `grafana.yuandrk.net` | `http://k3s-master:80` | Monitoring dashboards |
| Headlamp | `headlamp.yuandrk.net` | `http://k3s-master:80` | K8s dashboard |
| Uptime Kuma | `uptime.yuandrk.net` | `http://k3s-master:80` | Status page |
| pgAdmin | `pgadmin.yuandrk.net` | `http://k3s-master:80` | PostgreSQL admin |
| Authentik | `auth.yuandrk.net` | `https://k3s-master:443` | SSO (noTLSVerify) |

**Tunnel Configuration**:
- **Tunnel ID**: `4a6abf9a-d178-4a56-9586-a3d77907c5f1`
- **Tunnel Name**: `homeserver`
- **Deployment**: Cloudflared systemd service on k3s-master

## CI/CD Workflows

### GitHub Actions Authentication

All workflows use **AWS OIDC** (no static credentials):

```yaml
- uses: aws-actions/configure-aws-credentials@v5
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: eu-west-2
```

### Workflow: `terraform-plan.yml`

**Triggers**:
- Pull requests to `main` branch
- Changes to `terraform/live/homelab/cloudflare/**`
- Manual trigger (`workflow_dispatch`)

**Steps**:
1. Checkout code
2. AWS OIDC authentication
3. Terraform init (with `backend.hcl`)
4. Terraform validate
5. Terraform plan
6. Upload plan artifact
7. Comment PR with plan output

**Concurrency**: Cancels outdated runs for the same PR

### Workflow: `terraform-apply.yml`

**Triggers**:
- Push to `main` branch
- Changes to `terraform/live/homelab/cloudflare/**`
- Manual trigger (`workflow_dispatch`)

**Protection**: Uses `environment: homelab` for approval gates

**Steps**:
1. Checkout code
2. AWS OIDC authentication
3. Terraform init
4. Safety plan
5. Apply (with `auto-approve` after environment approval)

## Version Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| Terraform | `>= 1.5.0` | S3 native locking requires 1.13+ in practice |
| AWS Provider | `~> 6.0` | Latest stable |
| Cloudflare Provider | `~> 5.0` | Simplified from `>= 5.3.0, < 6.0` |
| GitHub Actions | `v5` | Latest for OIDC support |

## GitHub Secrets

Required secrets in repository settings:

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN` | IAM role ARN for OIDC: `arn:aws:iam::756755582140:role/GitHubActionsTerraformRole` |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token with Zone/Tunnel permissions |
| `CLOUDFLARE_ZONE_ID` | Zone ID for `yuandrk.net` |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID |

## Local Development

### Prerequisites

1. **AWS CLI** configured with credentials (or use `AWS_PROFILE`)
2. **Terraform** >= 1.5.0 installed
3. **Cloudflare API token** (for local testing)

### Initialize Terraform

```bash
cd terraform/live/homelab/cloudflare
terraform init -backend-config=backend.hcl
```

### Plan Changes

```bash
terraform plan
```

### Apply Changes (Local)

```bash
terraform apply
```

**Note**: Local applies bypass GitHub environment protection. Use CI/CD for production changes.

## Backend Configuration

All stacks use S3 backend with native locking:

```hcl
# backend.tf
terraform {
  backend "s3" {}
}
```

Configuration is provided via `backend.hcl`:

```hcl
bucket       = "terraform-state-homelab-yuandrk"
key          = "cloudflare/terraform.tfstate"  # varies per stack
region       = "eu-west-2"
encrypt      = true
use_lockfile = true
```

**Why separate files?**
- Inline `backend "s3" { ... }` blocks don't support `use_lockfile`
- External `backend.hcl` allows S3 native locking parameter
- Cleaner separation of environment-specific config

## Module: `modules/tunnel`

Reusable module for creating Cloudflare Tunnel DNS records.

**Inputs**:
```hcl
variable "account_id"         # Cloudflare account ID
variable "zone_id"            # DNS zone ID
variable "existing_tunnel_id" # Tunnel ID to use
variable "hostname"           # Public hostname (e.g., pihole.yuandrk.net)
variable "service"            # Backend service URL
```

**Outputs**:
```hcl
output "tunnel_id"     # Tunnel ID
output "tunnel_cname"  # CNAME target: {tunnel_id}.cfargotunnel.com
output "hostname"      # Public hostname
```

**Usage Example**:
```hcl
module "pihole_dns" {
  source = "../../../modules/tunnel"

  account_id         = var.cloudflare_account_id
  zone_id            = var.cloudflare_zone_id
  existing_tunnel_id = local.tunnel_id
  hostname           = "pihole.yuandrk.net"
  service            = "http://127.0.0.1:8081"
}
```

## Troubleshooting

### OIDC Authentication Failures

**Error**: `Not authorized to perform sts:AssumeRoleWithWebIdentity`

**Causes**:
- Trust policy doesn't match repository/branch
- OIDC provider not created
- Role ARN secret incorrect

**Fix**:
```bash
# Check trust policy
aws iam get-role --role-name GitHubActionsTerraformRole

# Verify OIDC provider exists
aws iam list-open-id-connect-providers
```

### S3 Backend Locking Issues

**Error**: `Unsupported argument: use_lockfile`

**Cause**: Using inline backend block instead of external `backend.hcl`

**Fix**: Ensure `backend.tf` has empty block and configuration is in `backend.hcl`

### Cloudflare Provider Errors

**Error**: `Invalid Configuration for Read-Only Attribute` (warp_routing)

**Cause**: Attempting to set read-only computed attributes

**Fix**: Remove `warp_routing` from config block - provider manages it automatically

## Best Practices

1. **Always use CI/CD** for production changes
2. **Never commit** `terraform.tfvars` with secrets
3. **Use backend.hcl** for S3 native locking configuration
4. **Pin provider versions** to avoid breaking changes
5. **Test locally** with `terraform plan` before opening PR
6. **Review plans** carefully in PR comments before merging
7. **Use environment protection** for apply workflows

## Migration Notes

### From DynamoDB to S3 Native Locking

If migrating from DynamoDB locking:

1. Update `backend.hcl` to use `use_lockfile = true`
2. Remove `dynamodb_table` parameter
3. Run `terraform init -migrate-state`
4. Delete DynamoDB table after successful migration
5. Update IAM policies to remove DynamoDB permissions

### From Old Structure to `live/homelab/`

Previous structure had roots at `terraform/{bootstrap,cloudflare}`. Current structure:
- Moved to `terraform/live/homelab/{aws-bootstrap,cloudflare}`
- Module paths updated: `source = "../../../modules/tunnel"`
- State keys remain unchanged in S3
