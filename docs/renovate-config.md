# Renovate Configuration Guide

## Overview

Renovate is a dependency update automation tool that monitors your repository for outdated dependencies and creates pull requests to update them. This guide explains the simplified configuration focused exclusively on Docker images and Helm charts.

## Philosophy: Focused Monitoring

This configuration **only monitors**:
- ✅ **Docker images** in applications and infrastructure
- ✅ **Helm chart versions**

Everything else is **explicitly disabled**:
- ❌ GitHub Actions (separate manual updates)
- ❌ Terraform providers/modules (managed via CI/CD workflows)
- ❌ FluxCD system components (manual upgrades only)
- ❌ npm/pip/other package managers

This keeps Renovate focused on what matters most in a Kubernetes homelab: container images and Helm charts.

## Current Configuration

The source of truth is [`renovate.json`](../renovate.json) in the repository root. Key settings (don't trust this table blindly — the JSON wins if they disagree):

| Setting | Value |
|---------|-------|
| Schedule | `* 0-5 * * 1` — Mondays 00:00–05:00 (Europe/London) |
| Managers | `kubernetes`, `flux`, `helm-values`, `helmv3` only |
| File scope | `apps/**/*.yaml` (kubernetes + flux managers via `managerFilePatterns`) |
| PR limit | 3 concurrent, `rebaseWhen: behind-base-branch` |
| Dashboard | Dependency Dashboard issue enabled |
| Security | `vulnerabilityAlerts` + `osvVulnerabilityAlerts` enabled |
| Grouping | `app-images` (Docker images in `apps/`), `helm-charts` (helm datasource) |
| Automerge | Patch updates of `actualbudget/actual-server` only |

## Configuration Explained

### Base Settings

- **`extends: ["config:recommended"]`** - Uses Renovate's recommended default settings
- **`timezone: "Europe/London"`** + **`schedule: ["* 0-5 * * 1"]`** - Renovate only runs early Monday morning to batch updates into one weekly window
- **`enabledManagers`** - **CRITICAL**: Only enables `kubernetes`, `flux`, `helm-values`, and `helmv3` managers (disables everything else by default)

### Pull Request Management

- **`prConcurrentLimit: 3`** - Maximum 3 open PRs at once
- **`labels: ["dependencies", "renovate"]`** - Automatically adds these labels to all Renovate PRs
- **`assignees: ["yuandrk"]`** - Assigns all PRs to yuandrk for review

### File Matching

- **`managerFilePatterns`** restricts the `kubernetes` and `flux` managers to `apps/**/*.yaml`
- **Note**: `clusters/` (FluxCD system components) and `infrastructure/` are outside the matched patterns

### Explicit Exclusions

- **GitHub Actions disabled** - `enabled: false` for `github-actions` manager
- **Terraform disabled** - `enabled: false` for `terraform` and `terraform-version` managers

### Update Policy & Grouping

- **App Docker images grouped** - All Docker image updates in `apps/` bundled into "app-images" PRs
- **Helm charts grouped** - All Helm chart updates bundled into "helm-charts" PRs
- **Patch automerge** - Patch updates for ActualBudget auto-merge after CI passes

## Monitored Dependencies

Renovate **only monitors** Docker images and Helm charts under `apps/`, currently:

- **ActualBudget** - `actualbudget/actual-server`
- **n8n** - `n8nio/n8n`
- **Immich** - chart + component images (`ghcr.io/immich-app/*`, valkey)
- **Whisper** - `ghcr.io/speaches-ai/speaches`
- **MCP Slack Bot** - `ghcr.io/yuandrk/mcp-slack-bot`

### Explicitly NOT Monitored

These are intentionally disabled and require manual updates:
- ❌ **FluxCD system components** - `clusters/prod/flux-system/gotk-components.yaml`
- ❌ **GitHub Actions** - `.github/workflows/*.yml`
- ❌ **Terraform providers/modules** - `terraform/**/*.tf` (managed by CI/CD workflows)
- ❌ **npm/pip/go.mod** - Not applicable to this Kubernetes-focused homelab

## How It Works

1. **Weekly Scan**: Early Monday morning, Renovate scans `apps/` for Docker images and Helm charts
2. **PR Creation**: Creates up to 3 PRs for available updates (grouped by category)
3. **Manual Review**: You review, test, and merge the PRs when ready
4. **Auto-merge**: Patch updates for ActualBudget merge automatically
5. **Dependency Dashboard**: Check the "Dependency Dashboard" issue for all pending updates

**What Renovate Scans**:
- Docker image tags in Kubernetes Deployments, StatefulSets, DaemonSets
- Helm chart versions in FluxCD HelmRelease manifests
- Container images referenced in HelmRelease `values` sections

**What Renovate Ignores**:
- FluxCD system manifests in `clusters/prod/flux-system/`
- GitHub Actions workflow files
- Terraform configuration files
- Any other package managers or dependency types

## Common Customizations

### Change Schedule

Run only on Sundays:
```json
"schedule": ["on sunday"]
```

Run daily at night:
```json
"schedule": ["after 10pm every weekday", "every weekend"]
```

### Re-enable Terraform Updates (if needed)

If you want to re-enable Terraform monitoring, remove the disable rule and optionally group updates:
```json
"packageRules": [
  {
    "description": "Group Terraform updates",
    "matchDatasources": ["terraform-provider", "terraform-module"],
    "groupName": "terraform"
  }
]
```

**Note**: Terraform is currently managed via GitHub Actions CI/CD workflows, so Renovate monitoring is disabled.

### Enable Automerge for Patch Updates

Automatically merge small patch updates:
```json
"packageRules": [
  {
    "matchUpdateTypes": ["patch"],
    "automerge": true,
    "automergeType": "pr"
  }
]
```

### Ignore Specific Dependencies

Skip updates for a specific package:
```json
"packageRules": [
  {
    "matchPackageNames": ["n8nio/n8n"],
    "enabled": false
  }
]
```

## Useful Commands

### Check Renovate PRs
```bash
gh pr list --label renovate
```

### View Dependency Dashboard
```bash
gh issue list --label renovate
```

### Test Configuration Locally
```bash
# Install Renovate CLI (optional)
npm install -g renovate

# Dry run (requires GitHub token)
renovate --dry-run --token=$GITHUB_TOKEN yuandrk/homelabops
```

## Best Practices

1. **Focused Monitoring**: Only monitor what matters (Docker images + Helm charts)
2. **Separate Concerns**: Terraform and GitHub Actions have their own update mechanisms
3. **Manual FluxCD Upgrades**: FluxCD system components upgraded manually for stability
4. **Test Updates**: Use a dev branch to test major updates before merging to main
5. **Monitor Dashboard**: Check the Dependency Dashboard issue regularly
6. **Group Updates**: Related dependencies grouped together (app-images, infra-images, helm-charts)
7. **Schedule Wisely**: A single weekly window (Monday 00:00–05:00) avoids disrupting daily operations

## Troubleshooting

### Renovate Not Creating PRs

1. Check the Dependency Dashboard issue for rate limits or errors
2. Verify GitHub App permissions (Settings → Integrations → Renovate)
3. Check logs at https://developer.mend.io/github/yuandrk/homelabops

### Too Many PRs

Reduce `prConcurrentLimit` or adjust schedule to less frequent runs.

### PRs Not Automerging

Ensure branch protection rules allow Renovate to merge (if automerge is enabled).

## Resources

- [Renovate Documentation](https://docs.renovatebot.com/)
- [Configuration Options](https://docs.renovatebot.com/configuration-options/)
- [Package Rules](https://docs.renovatebot.com/configuration-options/#packagerules)
- [Presets](https://docs.renovatebot.com/presets-default/)

## Related Documentation

- `docs/terraform-guide.md` - Terraform dependency management
- `CLAUDE.md` - Development workflow and GitOps practices
