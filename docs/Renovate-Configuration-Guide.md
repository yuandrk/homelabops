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
  "prConcurrentLimit": 3,
  "labels": ["dependencies", "renovate"],
  "assignees": ["yuandrk"],
  "packageRules": [
    {
      "description": "Require manual approval for all updates",
      "matchUpdateTypes": ["major", "minor", "patch"],
      "automerge": false
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

- **`prConcurrentLimit: 3`** - Maximum 3 open PRs at once to avoid overwhelming the review queue
- **`labels: ["dependencies", "renovate"]`** - Automatically adds these labels to all Renovate PRs
- **`assignees: ["yuandrk"]`** - Assigns all PRs to yuandrk for review

### Update Policy

- **`automerge: false`** - All updates require manual review and approval (safe default for homelab)

## Detected Dependencies

Renovate automatically monitors:

- **FluxCD components** (`clusters/prod/flux-system/gotk-components.yaml`)
- **GitHub Actions** (`.github/workflows/*.yml`)
- **Terraform providers and modules** (`terraform/**/*.tf`)
- **Helm charts** (`apps/**/helm-release.yaml`)

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
