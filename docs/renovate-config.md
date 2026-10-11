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
| Flux itself: `clusters/prod/flux-system/gotk-components.yaml` | the `flux` manager's default file pattern, e.g. the `fluxcd/flux2` v2.9.4 PR |

Not covered: GitHub Actions, Terraform providers, and anything else. Those are bumped by hand.

## How PRs arrive

- **Mondays, 00:00–05:00** Europe/London, at most 3 PRs open at a time, with a Dependency
  Dashboard issue.
- **Grouped** so that one failing chart cannot block the rest: `app-images`, `app-helm-charts`,
  `infra-images`, `infra-helm-charts`.
- **Automerge**: only patch updates of `actualbudget/actual-server`.
- **Vulnerability alerts** (GitHub and OSV) raise PRs outside the schedule.

## Traps

- **Tags that look like downgrades.** `linuxserver/qbittorrent` still carries legacy tags named
  after its Ubuntu base (14.x, 20.x), which Renovate ranks above the real 5.x releases. It once
  proposed going from 5.2.3 to an image from 2021. The JSON caps it with `allowedVersions: "<14"`.
  SearXNG's `YYYY.M.D-<sha>` tags are the same risk: read the first `infra-images` PR that
  touches it carefully.
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
  before merging ([runbooks/upgrade-k3s.md](runbooks/upgrade-k3s.md#before)).

## Checking on it

- The Dependency Dashboard issue in the repository lists what is pending and why.
- Logs: <https://developer.mend.io/github/yuandrk/homelabops>
