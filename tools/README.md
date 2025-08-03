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

### `setup-repo-metadata.sh`
**Purpose**: Configure GitHub repository About section and Topics

**Usage**:
```bash
# First authenticate with GitHub CLI
gh auth login

# Run the setup script
./tools/setup-repo-metadata.sh
```

**What it does**:
- Sets repository description for the About section
- Adds homepage URL (https://chat.yuandrk.net)
- Adds comprehensive topics for discoverability:
  - homelab, gitops, k3s, kubernetes
  - fluxcd, terraform, ansible
  - cloudflare-tunnel, infrastructure-as-code
  - raspberry-pi, multi-arch, llm, open-webui
  - self-hosted, pihole, mermaid-diagrams

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
