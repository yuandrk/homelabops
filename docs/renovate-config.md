# Renovate

Renovate proposes version bumps as PRs, and it is the only way a pinned version changes
([why](decisions.md#2026-08-01--renovate-owns-version-bumps)). Unpinned versions are another story
(see [Traps](#traps)). [`renovate.json`](../renovate.json) is the source of truth.

## What it covers

| Covered | How |
|---------|-----|
| Container images in `apps/` and `infrastructure/` manifests and HelmRelease values | managers `kubernetes`, `helm-values` |
| Helm chart versions in HelmReleases | managers `flux`, `helmv3` |
| Flux itself: `clusters/prod/flux-system/gotk-components.yaml` | the `flux` manager's default file pattern, which `managerFilePatterns` extends rather than replaces. Releases arrive as `fluxcd/flux2` PRs |
| The Cloudflare Terraform provider, in `terraform/live/homelab/cloudflare/` only | manager `terraform` with `rangeStrategy: update-lockfile`. The constraint stays `~> 5.0` and Renovate bumps the committed `.terraform.lock.hcl`, so `terraform-plan.yml` runs before `main` sees it ([why](decisions.md#2026-09-26--the-cloudflare-provider-is-pinned-by-a-committed-lock-file)) |

GitHub Actions and the other Terraform stacks are bumped by hand. Two images need care:

- **Fleet's `imageTag`** is a bare tag with no repository, so Renovate cannot see it. Fleet chart
  versions map 1:1 to Fleet releases: bump `imageTag` together with the chart.
- **Immich's server and machine-learning images** are visible only because their HelmRelease
  values carry `repository:` next to `tag:`. Keep it that way.

## How PRs arrive

Mondays before 06:00 Europe/London, at most three open, with a Dependency Dashboard issue. They
are grouped so that one failing chart cannot block the rest: `app-images`, `app-helm-charts`,
`infra-images`, `infra-helm-charts`, `terraform-cloudflare`, and `immich`, whose server, machine
learning and chart arrive together because an Immich upgrade migrates its database. Only patch
updates of `actualbudget/actual-server` automerge. Vulnerability alerts raise PRs outside the
schedule.

## Traps

- **Versions that Renovate ranks wrongly:**

  | Package | Trap | Guard |
  |---------|------|-------|
  | `mysql` (Fleet) | 26.x is Oracle's innovation track. Fleet supports 8.x only, and MySQL cannot downgrade an upgraded data dictionary in place | `allowedVersions: "<8.5"` |
  | `valkey/valkey` | A short tag such as `9.2-alpine` can point at a release candidate | Pin full versions (`9.1.2-alpine`); Renovate skips the `-rcN` tags |
  | `n8nio/n8n` | Betas use plain semver tags | None. Before merging, check that the tag's digest matches `n8nio/n8n:stable` |
  | SearXNG | `YYYY.M.D-<sha>` tags | None. Read its `infra-images` PRs carefully |

- **A closed PR blocks that exact version.** Only a newer release gets a new PR. To get a closed
  one back, reopen it from the Dependency Dashboard.
- **The infrastructure charts float.** All four infrastructure HelmReleases
  (kube-prometheus-stack, cloudflared, the 1Password operator, the NFS provisioner) use
  `version: ">=x"`. helm-controller installs the newest matching chart on its
  next run, **major versions included**, with no PR and no review, so the `infra-helm-charts`
  group never fires. Only the app charts (Immich, Fleet) are pinned
  ([TODO](TODO.md#reliability)).
- **cloudflared's image floats too.** Its chart declares the app version `latest` and the
  HelmRelease sets no tag, so the pods presumably run whatever `cloudflare/cloudflared:latest`
  was when their node pulled it.
- **Flux bumps need a matching cluster.** Check `flux check --pre` against the k3s version before
  merging ([runbooks/upgrade-k3s.md](runbooks/upgrade-k3s.md#before)). The `fluxcd/flux2` PR's
  diff should change only versions and controller images.
- **Provider lock hashes are per platform.** A lock file bumped on Linux carries only that
  platform's `h1:` hash. If `terraform init` on a Mac complains, run
  `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64` and commit.

## Checking on it

The Dependency Dashboard issue lists what is pending and why. Logs:
<https://developer.mend.io/github/yuandrk/homelabops>
