# Terraform Infrastructure

## Structure

```
terraform/live/homelab/
├── aws-bootstrap/      # S3 backend (one-time setup)
├── aws-oidc/           # GitHub OIDC provider (one-time setup)
├── cloudflare/         # DNS & Tunnels (actively managed via CI/CD)
└── fluxcd/             # FluxCD bootstrap (historical)
```

## CI/CD Workflows

- `terraform-plan.yml` - Runs on PRs, comments plan output
- `terraform-apply.yml` - Runs on push to main, applies changes

## Key Details

- **Backend**: S3 with native locking (Terraform 1.13+), no DynamoDB needed
- **Auth**: GitHub Actions uses AWS OIDC via `GitHubActionsTerraformRole`
- **Trust**: Scoped to `yuandrk/homelabops` repository
- **Environments**: the apply job runs in GitHub environment `homelab`, which has no required
  reviewers, so a merge to `main` applies without an approval
- **Rule**: Always use CI/CD for production changes, never apply locally to main
- **Full docs**: `docs/terraform-guide.md`
