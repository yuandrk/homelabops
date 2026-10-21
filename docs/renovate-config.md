# Renovate

Renovate proposes version bumps as PRs, and it is the only way a pinned version changes
([why](decisions.md#2026-08-01--renovate-owns-version-bumps)). Every chart and image is pinned to
an exact version, because a range such as `>=1.0` never gets a PR: helm-controller installs each
new release by itself, majors included. [`renovate.json`](../renovate.json) is the source of truth.

## What it covers

| Covered | How |
|---------|-----|
| Container images in `apps/` and `infrastructure/` manifests | manager `kubernetes` |
| Helm chart versions in HelmReleases, and the images in their values | manager `flux`. `helm-values` and `helmv3` are enabled but find nothing: the repository has no `values.yaml` or `Chart.yaml` |
| Flux itself: `clusters/prod/flux-system/gotk-components.yaml` | the `flux` manager's default file pattern, which `managerFilePatterns` extends rather than replaces. Releases arrive as `fluxcd/flux2` PRs |
| The Cloudflare Terraform provider, in `terraform/live/homelab/cloudflare/` only | manager `terraform` with `rangeStrategy: update-lockfile`. The constraint stays `~> 5.0` and Renovate bumps the committed `.terraform.lock.hcl`, so `terraform-plan.yml` runs before `main` sees it ([why](decisions.md#2026-09-26--the-cloudflare-provider-is-pinned-by-a-committed-lock-file)) |

GitHub Actions and the other Terraform stacks are bumped by hand. Images set in chart values need
care:

- **Fleet's `imageTag`** is a bare tag with no repository, so Renovate cannot see it. Fleet chart
  versions map 1:1 to Fleet releases: bump `imageTag` together with the chart.
- **Immich's server and machine-learning images, and cloudflared's,** are visible only because
  their HelmRelease values carry `repository:` next to `tag:`. Keep it that way.

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
- **A template can hide a whole file.** The `flux` manager deletes every `{{ }}` before it parses
  a manifest, and silently skips one that is then invalid YAML, so its chart and images get no
  PRs. A block scalar whose leading lines are only templates is enough, if one of them is indented
  deeper than the first line of text. Give such a block an explicit indentation (`|2-`, as the
  Alertmanager payloads in the kube-prometheus-stack HelmRelease do). After editing a file with
  templates, check that it is still listed under the Dependency Dashboard's detected dependencies.
- **Flux bumps need a matching cluster.** Check `flux check --pre` against the k3s version before
  merging ([runbooks/upgrade-k3s.md](runbooks/upgrade-k3s.md#before)). The `fluxcd/flux2` PR's
  diff should change only versions and controller images.
- **Provider lock hashes are per platform.** A lock file bumped on Linux carries only that
  platform's `h1:` hash. If `terraform init` on a Mac complains, run
  `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64` and commit.

## Checking on it

The Dependency Dashboard issue lists what is pending and why. Logs:
<https://developer.mend.io/github/yuandrk/homelabops>
