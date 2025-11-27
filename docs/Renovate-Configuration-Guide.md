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

The `renovate.json` file in the repository root contains the Renovate configuration:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "timezone": "Europe/London",
  "schedule": ["every weekend"],
  "prConcurrentLimit": 3,
  "labels": ["dependencies", "renovate"],
  "assignees": ["yuandrk"],

  "enabledManagers": ["kubernetes", "flux", "helm-values", "helmv3"],

  "kubernetes": {
    "fileMatch": ["apps/.+\\.yaml$", "infrastructure/.+\\.yaml$"]
  },
  "flux": {
    "fileMatch": ["apps/.+\\.yaml$", "infrastructure/.+\\.yaml$"]
  },

  "packageRules": [
    {
      "description": "Disable GitHub Actions updates",
      "matchManagers": ["github-actions"],
      "enabled": false
    },
    {
      "description": "Disable Terraform updates",
      "matchManagers": ["terraform", "terraform-version"],
      "enabled": false
    },
    {
      "description": "Disable FluxCD system components",
      "matchFileNames": ["clusters/prod/flux-system/**"],
      "enabled": false
    },
    {
      "description": "Group app Docker images",
      "matchDatasources": ["docker"],
      "matchFileNames": ["apps/**"],
      "groupName": "app-images"
    },
    {
      "description": "Group infrastructure Docker images",
      "matchDatasources": ["docker"],
      "matchFileNames": ["infrastructure/**"],
      "groupName": "infra-images"
    },
    {
      "description": "Group Helm charts",
      "matchDatasources": ["helm"],
      "groupName": "helm-charts"
    },
    {
      "description": "Automerge patch updates for stable apps",
      "matchUpdateTypes": ["patch"],
      "matchPackageNames": [
        "actualbudget/actual-server",
        "louislam/uptime-kuma"
      ],
      "automerge": true,
      "automergeType": "pr"
    }
  ]
}
```

## Configuration Explained

### Base Settings

- **`extends: ["config:recommended"]`** - Uses Renovate's recommended default settings
- **`timezone: "Europe/London"`** - Sets timezone for schedule
- **`schedule: ["every weekend"]`** - Renovate only runs on weekends to avoid disrupting weekday operations
- **`enabledManagers`** - **CRITICAL**: Only enables `kubernetes`, `flux`, `helm-values`, and `helmv3` managers (disables everything else by default)

### Pull Request Management

- **`prConcurrentLimit: 3`** - Maximum 3 open PRs at once
- **`labels: ["dependencies", "renovate"]`** - Automatically adds these labels to all Renovate PRs
- **`assignees: ["yuandrk"]`** - Assigns all PRs to yuandrk for review

### File Matching

- **`kubernetes.fileMatch`** - Scans `apps/` and `infrastructure/` directories for Kubernetes manifests
- **`flux.fileMatch`** - Detects FluxCD HelmRelease resources in the same directories
- **Note**: `clusters/` directory excluded from scanning to avoid FluxCD system components

### Explicit Exclusions

- **GitHub Actions disabled** - `enabled: false` for `github-actions` manager
- **Terraform disabled** - `enabled: false` for `terraform` and `terraform-version` managers
- **FluxCD system components disabled** - `clusters/prod/flux-system/**` files excluded

### Update Policy & Grouping

- **App Docker images grouped** - All Docker image updates in `apps/` bundled into "app-images" PRs
- **Infrastructure images grouped** - Infrastructure Docker images bundled into "infra-images" PRs
- **Helm charts grouped** - All Helm chart updates bundled into "helm-charts" PRs
- **Patch automerge** - Patch updates for ActualBudget and Uptime Kuma auto-merge after CI passes

## Monitored Dependencies

Renovate **only monitors** these dependency types:

### Applications (Docker Images)
- **ActualBudget** - `actualbudget/actual-server`
- **Uptime Kuma** - `louislam/uptime-kuma`
- **pgAdmin** - `dpage/pgadmin4`
- **n8n** - `n8nio/n8n`

### Infrastructure (Docker Images)
- **NVIDIA Device Plugin** - `nvcr.io/nvidia/k8s-device-plugin`
- **Kube State Metrics** - `registry.k8s.io/kube-state-metrics/kube-state-metrics`
- **Headlamp Flux Plugin** - `ghcr.io/headlamp-k8s/headlamp-plugin-flux`

### Helm Charts
- **open-webui** - Helm chart updates
- **Headlamp** - Helm chart updates
- **kube-prometheus-stack** - Helm chart updates (monitoring stack)

### Explicitly NOT Monitored

These are intentionally disabled and require manual updates:
- ❌ **FluxCD system components** - `clusters/prod/flux-system/gotk-components.yaml`
- ❌ **GitHub Actions** - `.github/workflows/*.yml`
- ❌ **Terraform providers/modules** - `terraform/**/*.tf` (managed by CI/CD workflows)
- ❌ **npm/pip/go.mod** - Not applicable to this Kubernetes-focused homelab

## How It Works

1. **Weekend Scan**: Every weekend, Renovate scans `apps/` and `infrastructure/` for Docker images and Helm charts
2. **PR Creation**: Creates up to 3 PRs for available updates (grouped by category)
3. **Manual Review**: You review, test, and merge the PRs when ready
4. **Auto-merge**: Patch updates for ActualBudget and Uptime Kuma merge automatically
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
    "matchPackageNames": ["open-webui/open-webui"],
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
7. **Schedule Wisely**: Weekend-only runs avoid disrupting weekday operations

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

- `docs/Terraform/Terraform-Infrastructure-Guide.md` - Terraform dependency management
- `CLAUDE.md` - Development workflow and GitOps practices
