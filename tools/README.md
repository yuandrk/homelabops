# Tools Directory

This directory contains utility scripts and tools for managing the homelab infrastructure.

## Available Scripts

### `setup-branch-protection.sh`
**Purpose**: Configure GitHub branch protection rules for the dev branch

**Usage**:
```bash
# First authenticate with GitHub CLI
gh auth login

# Run the setup script
./tools/setup-branch-protection.sh
```

**What it does**:
- Creates branch protection rules for the `dev` branch
- Requires 1 pull request review before merging
- Prevents force pushes and branch deletion
- Enforces rules for administrators
- Dismisses stale reviews on new commits

**Prerequisites**:
- GitHub CLI installed (`brew install gh`)
- Authenticated with GitHub (`gh auth login`)
- Admin permissions on the repository

## Future Tools

This directory can be extended with additional scripts for:
- Cluster health checks
- Automated deployment scripts
- Infrastructure validation tools
- Backup and restore utilities
