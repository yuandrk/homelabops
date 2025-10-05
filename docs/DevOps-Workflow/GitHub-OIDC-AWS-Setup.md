# GitHub OIDC for AWS Authentication

This document describes the GitHub Actions OIDC integration with AWS for secure, credential-free Terraform deployments.

## Overview

GitHub Actions can authenticate to AWS using OpenID Connect (OIDC) instead of storing long-lived AWS credentials as secrets. This provides better security and follows AWS best practices.

## Architecture

```
GitHub Actions Workflow
  ↓ (generates JWT token)
AWS STS (Security Token Service)
  ↓ (validates token via OIDC provider)
Assumes IAM Role
  ↓ (temporary credentials)
Access S3 State Bucket
```

## Resources Created

The `terraform/github-oidc` module creates:

1. **AWS IAM OIDC Provider**: Trusts GitHub's token issuer
2. **IAM Role**: `GitHubActionsTerraformRole` - assumable by GitHub Actions
3. **IAM Policy**: Grants S3 state bucket access (read/write/list)

## Setup Instructions

### 1. Apply OIDC Module (One-time Setup)

```bash
cd terraform/github-oidc
terraform init
terraform plan
terraform apply
```

This creates the OIDC provider and IAM role in AWS.

### 2. Configure GitHub Repository Secret

```bash
# Get the role ARN from Terraform output
terraform output github_actions_role_arn

# Add to GitHub repository secrets
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::ACCOUNT_ID:role/GitHubActionsTerraformRole"
```

### 3. Use in GitHub Actions Workflow

```yaml
name: Terraform Plan/Apply

on:
  push:
    branches:
      - main

permissions:
  id-token: write  # Required for OIDC
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: eu-west-2

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve
```

## Configuration Details

### OIDC Provider Configuration

- **URL**: `https://token.actions.githubusercontent.com`
- **Client ID**: `sts.amazonaws.com`
- **Thumbprints**:
  - `6938fd4d98bab03faadb97b34396831e3780aea1`
  - `1c58a3a8518e8759bf075b76b750d4f2df264fcd`

### Trust Policy

The IAM role trust policy restricts access to specific repositories and branches:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:yuandrk/homelabops:ref:refs/heads/main"
      }
    }
  }]
}
```

### IAM Permissions

The role has the following S3 permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:PutObjectLockConfiguration",
      "s3:GetObjectLockConfiguration"
    ],
    "Resource": [
      "arn:aws:s3:::terraform-state-homelab-yuandrk",
      "arn:aws:s3:::terraform-state-homelab-yuandrk/*"
    ]
  }]
}
```

## S3 Native Locking

This setup uses **S3 native locking** instead of DynamoDB (available in Terraform 1.5+):

### Backend Configuration

```hcl
terraform {
  backend "s3" {
    bucket       = "terraform-state-homelab-yuandrk"
    key          = "path/to/state.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true  # Enable S3 native locking
  }
}
```

### Benefits

- ✅ No DynamoDB table required (cost savings)
- ✅ Simpler infrastructure
- ✅ Built-in S3 feature (no additional service)
- ✅ Same locking guarantees as DynamoDB

## Module Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `terraform_state_bucket` | S3 bucket name for Terraform state | Required |
| `aws_region` | AWS region | `eu-west-2` |
| `github_repos_branches` | Allowed repository:branch patterns | `["yuandrk/homelabops:ref:refs/heads/main"]` |
| `github_actions_role_name` | IAM role name | `GitHubActionsTerraformRole` |

## Module Outputs

| Output | Description |
|--------|-------------|
| `oidc_provider_arn` | ARN of the GitHub OIDC provider |
| `github_actions_role_arn` | ARN of the IAM role (store in GitHub secrets) |
| `github_actions_role_name` | Name of the IAM role |

## Security Best Practices

1. **Scoped Access**: Role can only be assumed by specific repos/branches
2. **Temporary Credentials**: No long-lived credentials stored in GitHub
3. **Least Privilege**: S3 permissions limited to state bucket only
4. **Audit Trail**: All AWS API calls logged via CloudTrail
5. **Branch Protection**: Use with branch protection rules on `main`

## Troubleshooting

### Error: "No OpenIDConnect provider found"

- Verify OIDC provider exists: `aws iam list-open-id-connect-providers`
- Check provider URL is exactly: `https://token.actions.githubusercontent.com`

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

- Verify workflow has `permissions: id-token: write`
- Check trust policy matches your repo/branch pattern
- Ensure `sub` claim format: `repo:ORG/REPO:ref:refs/heads/BRANCH`

### Error: "Access Denied" on S3 operations

- Verify IAM policy is attached to role
- Check S3 bucket name matches in policy
- Ensure bucket region matches `aws-region` in workflow

## Migration from DynamoDB Locking

If migrating from DynamoDB locking:

1. Update backend config to use `use_lockfile = true`
2. Run `terraform init -migrate-state`
3. Remove DynamoDB table after successful migration
4. Update IAM policies to remove DynamoDB permissions

## Related Documentation

- [DevOps Workflow](./DevOps-Workflow.md)
- [SOPS Secrets Management](./SOPS-Secrets-Management.md)
- [Terraform Infrastructure](../Terraform/Terraform%20Homelab%20Infrastructure.md)
