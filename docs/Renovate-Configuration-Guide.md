# Renovate Configuration Guide

## Overview

Renovate is a dependency update automation tool that monitors your repository for outdated dependencies and creates pull requests to update them. This guide explains the current configuration and how to customize it.

## Current Configuration

The `renovate.json` file in the repository root contains the Renovate configuration:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "timezone": "Europe/London",
  "schedule": ["every weekend"],
  "prConcurrentLimit": 5,
  "labels": ["dependencies", "renovate"],
  "assignees": ["yuandrk"],
  "kubernetes": {
    "fileMatch": ["apps/.+\\.yaml$", "infrastructure/.+\\.yaml$", "clusters/.+\\.yaml$"]
  },
  "flux": {
    "fileMatch": ["apps/.+\\.yaml$", "infrastructure/.+\\.yaml$", "clusters/.+\\.yaml$"]
  },
  "packageRules": [
    {
      "description": "Require manual approval for all updates",
      "matchUpdateTypes": ["major", "minor", "patch"],
      "automerge": false
    },
    {
      "description": "Group all app Docker image updates",
      "matchDatasources": ["docker"],
      "matchFileNames": ["apps/**"],
      "groupName": "app-images",
      "separateMinorPatch": true
    },
    {
      "description": "Group all infrastructure Docker image updates",
      "matchDatasources": ["docker"],
      "matchFileNames": ["infrastructure/**"],
      "groupName": "infrastructure-images",
      "separateMinorPatch": true
    },
    {
      "description": "Group Helm chart updates",
      "matchDatasources": ["helm"],
      "groupName": "helm-charts",
      "separateMinorPatch": true
    },
    {
      "description": "Pin headlamp-plugin-flux to specific version (avoid :latest)",
      "matchPackageNames": ["ghcr.io/headlamp-k8s/headlamp-plugin-flux"],
      "pinDigests": true
    },
    {
      "description": "Automerge patch updates for stable apps",
      "matchUpdateTypes": ["patch"],
      "matchPackageNames": [
        "actualbudget/actual-server",
        "louislam/uptime-kuma",
        "dpage/pgadmin4"
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

### Pull Request Management

- **`prConcurrentLimit: 5`** - Maximum 5 open PRs at once (increased from 3 for better app monitoring)
- **`labels: ["dependencies", "renovate"]`** - Automatically adds these labels to all Renovate PRs
- **`assignees: ["yuandrk"]`** - Assigns all PRs to yuandrk for review

### File Matching

- **`kubernetes.fileMatch`** - Explicitly scans `apps/`, `infrastructure/`, and `clusters/` directories for Kubernetes manifests
- **`flux.fileMatch`** - Detects FluxCD HelmRelease resources in the same directories

### Update Policy & Grouping

- **Default: Manual approval** - All major/minor/patch updates require review
- **App Docker images grouped** - All Docker image updates in `apps/` bundled into "app-images" PRs
- **Infrastructure images grouped** - Infrastructure Docker images bundled into "infrastructure-images" PRs
- **Helm charts grouped** - All Helm chart updates bundled into "helm-charts" PRs
- **Patch automerge** - Patch updates for ActualBudget, Uptime Kuma, and pgAdmin auto-merge after CI passes
- **Pin :latest tags** - Headlamp Flux plugin pinned to digest to avoid :latest drift

## Detected Dependencies

Renovate automatically monitors:

### Applications (Docker Images)
- **ActualBudget** - `actualbudget/actual-server:25.8.0`
- **Uptime Kuma** - `louislam/uptime-kuma:1.23.15`
- **pgAdmin** - `dpage/pgadmin4:8.12`
- **n8n** - `n8nio/n8n:1.120.3`

### Infrastructure (Docker Images)
- **NVIDIA Device Plugin** - `nvcr.io/nvidia/k8s-device-plugin:v0.16.2`
- **Kube State Metrics** - `registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.0`
- **Headlamp Flux Plugin** - `ghcr.io/headlamp-k8s/headlamp-plugin-flux` (pinned digest)

### Helm Charts
- **open-webui** - Chart version `8.10.0`
- **Headlamp** - Chart version `>=0.21.0`, image `v0.26.0`

### Other
- **FluxCD components** - `clusters/prod/flux-system/gotk-components.yaml`
- **GitHub Actions** - `.github/workflows/*.yml`
- **Terraform providers/modules** - `terraform/**/*.tf`

## How It Works

1. **Weekend Scan**: Every weekend, Renovate scans for outdated dependencies
2. **PR Creation**: Creates up to 3 PRs for available updates
3. **Manual Review**: You review, test, and merge the PRs when ready
4. **Dependency Dashboard**: Check the "Dependency Dashboard" issue for all pending updates

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

### Group Related Updates

Group all Terraform updates together:
```json
"packageRules": [
  {
    "matchDatasources": ["terraform-provider", "terraform-module"],
    "groupName": "terraform",
    "schedule": ["every weekend"]
  }
]
```

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

1. **Start Conservative**: Manual review for all updates (current config)
2. **Test Updates**: Use a dev branch to test major updates before merging to main
3. **Monitor Dashboard**: Check the Dependency Dashboard issue regularly
4. **Group Updates**: Consider grouping related dependencies together
5. **Schedule Wisely**: Run during low-traffic periods (weekends work well for homelabs)

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
