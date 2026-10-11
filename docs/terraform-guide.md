# Terraform

Terraform manages what lives outside the cluster. CI applies the Cloudflare edge on every merge.
The AWS pieces that let CI do that without stored keys were applied once, by hand.

## Stacks

All under `terraform/live/homelab/`:

| Stack | Manages | Applied by | State |
|-------|---------|------------|-------|
| `cloudflare/` | Per-app CNAMEs to the tunnel, the `*.home` wildcard, the tunnel's ingress rules | CI, on every merge that touches it | S3, `cloudflare/terraform.tfstate` |
| `aws-bootstrap/` | The state bucket `terraform-state-homelab-yuandrk` (eu-west-2): versioning, AES256, old versions expire after 90 days, public access blocked | once, by hand | S3, `global/bootstrap.tfstate` |
| `aws-oidc/` | GitHub's OIDC provider in AWS and the role `GitHubActionsTerraformRole` | once, by hand | **local**: there is no backend block, so the state file is wherever it was applied from |
| `fluxcd/` | Flux bootstrap: a deploy key and `flux_bootstrap_git` | once, by hand. A rebuild would use `flux bootstrap` instead ([runbook](runbooks/rebuild-k3s-master.md#5-secrets-and-flux)) | S3, `fluxcd/terraform.tfstate` |

Every S3 backend uses native locking (`use_lockfile = true`), so there is no DynamoDB table. The
settings sit in a separate `backend.hcl` per stack, because an inline `backend "s3" {}` block
rejects `use_lockfile`.

## The Cloudflare stack

- **Public apps** are the list `local.tunnel_services` in `cloudflare/main.tf`. Each entry
  becomes a proxied CNAME to `<tunnel-id>.cfargotunnel.com` and an ingress rule, and the rules
  end in `http_status:404`. To publish an app, append an entry and merge.
- **Internal apps** need nothing here. `cloudflare_dns_record.internal_wildcard` sends
  `*.home.yuandrk.net` to `internal_ingress_ip`, k3s-master's Tailscale address. If that address
  ever changes, this is the only line to edit.
- **Not managed here**: the tunnel itself (its ID is a local) and the proxied catch-all
  `*.yuandrk.net`. Both were made by hand.
- **The provider** is pinned by the committed `.terraform.lock.hcl`, which Renovate bumps
  ([renovate-config.md](renovate-config.md#what-it-covers)). The other stacks' providers are
  bumped by hand.

## CI

| Workflow | Runs on | Does |
|----------|---------|------|
| `terraform-plan.yml` | a PR that changes `terraform/live/homelab/cloudflare/**` | init, validate, plan, then comments the plan on the PR |
| `terraform-apply.yml` | a push to `main` with the same paths | a fresh plan, then apply, in the `homelab` environment, which has **no protection rules** |

Both authenticate to AWS through OIDC:

```
GitHub Actions job ──(OIDC JWT)──▶ AWS STS ──▶ GitHubActionsTerraformRole ──▶ S3 state bucket
```

- The role can only read and write the state bucket. Cloudflare access comes from the
  `CLOUDFLARE_API_TOKEN` secret, next to `AWS_ROLE_ARN`, `CLOUDFLARE_ZONE_ID` and
  `CLOUDFLARE_ACCOUNT_ID`.
- The trust policy matches the token's `sub` against `github_repos_branches`, whose live value
  is in an uncommitted `terraform.tfvars`. It must cover more than `ref:refs/heads/main`: a PR
  job presents `repo:yuandrk/homelabops:pull_request`, and the apply job, because it uses an
  environment, presents `repo:yuandrk/homelabops:environment:homelab`. That is why the live
  list includes `yuandrk/homelabops:*`.
- Jobs need `permissions: id-token: write`.

## Troubleshooting

| Error | Likely cause |
|-------|--------------|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | The job's `sub` is not in the trust policy (see above), or `id-token: write` is missing |
| `No OpenIDConnect provider found` | The provider URL must be exactly `https://token.actions.githubusercontent.com` |
| `Unsupported argument: use_lockfile` | Backend settings written inline instead of in `backend.hcl` |
| `Invalid Configuration for Read-Only Attribute` (`warp_routing`) | The tunnel config sets a computed attribute. Remove it |
