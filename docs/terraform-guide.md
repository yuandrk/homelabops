# Terraform

Terraform manages what lives outside the cluster. It applies the Cloudflare edge continuously,
from CI. Once, by hand, it set up the AWS pieces that let CI do that without stored keys.

## Stacks

All under `terraform/live/homelab/`:

| Stack | Manages | Applied by | State |
|-------|---------|------------|-------|
| `cloudflare/` | Per-app CNAMEs to the tunnel, the `*.home` wildcard, the tunnel's ingress rules | CI, on every merge that touches it | S3, `cloudflare/terraform.tfstate` |
| `aws-bootstrap/` | The state bucket `terraform-state-homelab-yuandrk` (eu-west-2): versioning, AES256, old versions expire after 90 days, public access blocked | once, by hand | S3, `global/bootstrap.tfstate` |
| `aws-oidc/` | GitHub's OIDC provider in AWS and the role `GitHubActionsTerraformRole` | once, by hand | **local**: there is no backend block, so the state file is wherever it was applied from |
| `fluxcd/` | Flux bootstrap: a deploy key and `flux_bootstrap_git` | once, by hand. A rebuild would use `flux bootstrap` instead ([runbook](runbooks/rebuild-k3s-master.md#5-secrets-and-flux)) | S3, `fluxcd/terraform.tfstate` |

Every S3 backend uses native locking (`use_lockfile = true`, Terraform 1.13+), so there is no
DynamoDB table. The settings sit in a separate `backend.hcl` per stack, because an inline
`backend "s3" {}` block rejects `use_lockfile`.

## The Cloudflare stack

- **Public apps** are the list `local.tunnel_services` in `cloudflare/main.tf`. Each entry
  becomes a proxied CNAME to `<tunnel-id>.cfargotunnel.com` and an ingress rule. The rules end
  in `http_status:404`. To publish an app, append an entry and merge.
- **Internal apps** need nothing here. `cloudflare_dns_record.internal_wildcard` sends
  `*.home.yuandrk.net` to k3s-master's Tailscale address, `internal_ingress_ip`. If that address
  ever changes, this is the only line to edit.
- **Not managed here**: the tunnel itself (its ID is a local) and the proxied catch-all
  `*.yuandrk.net`. Both were created by hand.

## CI

| Workflow | Runs on | Does |
|----------|---------|------|
| `terraform-plan.yml` | a PR that changes `terraform/live/homelab/cloudflare/**` | init, validate, plan, then comments the plan on the PR. Outdated runs for the same PR are cancelled |
| `terraform-apply.yml` | a push to `main` with the same paths | a fresh plan, then apply. The job runs in the `homelab` environment, which has **no protection rules**, so nothing waits for an approval |

Both run Terraform 1.13.3 and authenticate to AWS through OIDC:

```
GitHub Actions job ──(OIDC JWT)──▶ AWS STS ──▶ GitHubActionsTerraformRole ──▶ S3 state bucket
```

- The role can only read and write the state bucket. Cloudflare access comes from the
  `CLOUDFLARE_API_TOKEN` secret.
- The trust policy matches the token's `sub` against `github_repos_branches`, whose live value
  is in an uncommitted `terraform.tfvars`. It must cover more than `ref:refs/heads/main`: a PR
  job presents `repo:yuandrk/homelabops:pull_request`, and the apply job, because it uses an
  environment, presents `repo:yuandrk/homelabops:environment:homelab`. That is why the live
  list includes `yuandrk/homelabops:*`.
- Jobs need `permissions: id-token: write`.

Repository secrets: `AWS_ROLE_ARN`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ZONE_ID`,
`CLOUDFLARE_ACCOUNT_ID`. A fifth, `CLAUDE_CODE_OAUTH_TOKEN`, has had no user since the Claude
workflows were removed in `9aa8bbb`.

`main` has no branch protection, so the PR, with its plan comment, is a habit rather than a
gate.

## Rules

- Apply the Cloudflare stack only through CI, so that every change has its plan shown on a PR
  first.
  A Claude Code hook warns about a local `terraform apply`.
- Never commit `terraform.tfvars` or state. `.gitignore` covers both.
- Renovate does not touch Terraform. Provider versions are bumped by hand.

## Troubleshooting

| Error | Likely cause |
|-------|--------------|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | The job's `sub` is not in the trust policy (see above), or `id-token: write` is missing |
| `No OpenIDConnect provider found` | The provider URL must be exactly `https://token.actions.githubusercontent.com` |
| `Unsupported argument: use_lockfile` | Backend settings written inline instead of in `backend.hcl` |
| `Invalid Configuration for Read-Only Attribute` (`warp_routing`) | The tunnel config sets a computed attribute. Remove it |
