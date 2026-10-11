# Renovate

Renovate proposes version bumps as PRs. The Flux image-automation controllers were removed
([decisions.md](decisions.md#2026-08-01--renovate-owns-version-bumps)), so Renovate is the only
route by which a pinned version changes. Unpinned versions are a different story (see Traps).
The source of truth is [`renovate.json`](../renovate.json). Where this page and the JSON
disagree, the JSON wins.

## What it covers

| Covered | How |
|---------|-----|
| Container images in `apps/` and `infrastructure/` manifests and HelmRelease values | managers `kubernetes`, `helm-values` |
| Helm chart versions in HelmReleases | managers `flux`, `helmv3` |
| Flux itself: `clusters/prod/flux-system/gotk-components.yaml` | the `flux` manager's default file pattern, which `managerFilePatterns` extends rather than replaces. Releases arrive as `fluxcd/flux2` PRs |
| The Cloudflare Terraform provider, in `terraform/live/homelab/cloudflare/` only | manager `terraform` with `rangeStrategy: update-lockfile`. The constraint stays `~> 5.0`, Renovate bumps the committed `.terraform.lock.hcl`, and `terraform-plan.yml` runs on the PR before the bump reaches `main` ([why](decisions.md#2026-09-26--the-cloudflare-provider-is-pinned-by-a-committed-lock-file)) |

Not covered: GitHub Actions, the other Terraform stacks, and anything else. Those are bumped by
hand. Two images inside the covered paths need care:

- **Fleet's `imageTag`** in `apps/fleet/base/helm-release.yaml` is a bare tag with no repository,
  so Renovate cannot see it. Fleet chart versions map 1:1 to Fleet releases: bump `imageTag`
  together with the chart.
- **Immich's server and machine-learning images** are visible only because their HelmRelease
  values carry `repository:` next to `tag:`. Keep it that way.

## How PRs arrive

- **Mondays, 00:00–05:00** Europe/London, at most 3 PRs open at a time, rebased when behind
  `main`, with a Dependency Dashboard issue. PRs are labelled `dependencies` and `renovate`.
- **Grouped** so that one failing chart cannot block the rest: `app-images`, `app-helm-charts`,
  `infra-images`, `infra-helm-charts`, `terraform-cloudflare`, and `immich`. Immich's server,
  machine learning and chart arrive together in their own PR, because an Immich upgrade
  migrates its database.
- **Automerge**: only patch updates of `actualbudget/actual-server`.
- **Vulnerability alerts** (GitHub and OSV) raise PRs outside the schedule.

## Traps

- **Versions that Renovate ranks wrongly.** It cannot tell some pre-releases and incompatible
  lines from normal releases:

  | Package | Trap | Guard |
  |---------|------|-------|
  | `lscr.io/linuxserver/qbittorrent` | Legacy tags named after its Ubuntu base (14.x, 20.x) rank above the real 5.x releases. It once proposed going from 5.2.3 to an image from 2021 | `allowedVersions: "<14"` |
  | `mysql` (Fleet) | 26.x is Oracle's innovation track. Fleet supports 8.x only, and MySQL cannot downgrade an upgraded data dictionary in place | `allowedVersions: "<8.5"` |
  | `valkey/valkey` | A short tag such as `9.2-alpine` can point at a release candidate (`9.2.0-rc1`) | Pin full versions (`9.1.2-alpine`), and Renovate skips the `-rcN` tags |
  | `n8nio/n8n` | Betas use plain semver tags (on 2026-10-11 `2.43.3` was `beta`, `stable` was `2.42.6`) | None in config. Before merging, check that the tag's digest matches `n8nio/n8n:stable` |
  | SearXNG | `YYYY.M.D-<sha>` tags | None. Read the first `infra-images` PR that touches it carefully |

- **A closed PR blocks that exact version.** Renovate does not raise it again. Only a newer
  release gets a new PR, which is what happened to Flux v2.9 after PR #30 was closed while the
  cluster was too old for it. To get a closed one back, reopen it from the Dependency Dashboard.
- **Every infrastructure chart is an open-ended range.** All seven infrastructure HelmReleases
  (kube-prometheus-stack, Loki, Alloy, Headlamp, cloudflared, the 1Password operator, the NFS
  provisioner) use `version: ">=x"`. helm-controller installs the newest matching chart on its
  next run, **major versions included**, with no PR and no review. Since every new release
  satisfies the range, the `infra-helm-charts` group never fires. Only the app charts (Immich,
  Fleet) are pinned and reviewed. This has already happened: on 2026-10-11 the `>=6.0.0` Loki
  range was running chart 7.x, and kube-prometheus-stack, asked for `>=45.5.5`, was on 92.x.
- **cloudflared's image floats too.** Its chart declares the app version `latest`, and the
  HelmRelease sets no image tag, so the pods presumably run whatever `cloudflare/cloudflared:latest`
  was when their node pulled it. Renovate cannot see that.
- **Flux bumps need a matching cluster.** Check `flux check --pre` against the k3s version
  before merging ([runbooks/upgrade-k3s.md](runbooks/upgrade-k3s.md#before)). The `fluxcd/flux2`
  PR's diff should change only versions and controller images.
- **Provider lock hashes are per platform.** A lock-file bump made on Linux carries only that
  platform's `h1:` hash. If `terraform init` on a Mac then complains, run
  `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64` and commit.

## Checking on it

- The Dependency Dashboard issue in the repository lists what is pending and why.
- Logs: <https://developer.mend.io/github/yuandrk/homelabops>
