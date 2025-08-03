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

### `create-release.sh`
**Purpose**: Create tagged releases with automated release notes

**Usage**:
```bash
# Auto-generate next minor version
./tools/create-release.sh

# Specify version and release type
./tools/create-release.sh v1.1.0 minor
./tools/create-release.sh v1.0.1 patch  
./tools/create-release.sh v2.0.0 major
```

**What it does**:
- Auto-generates version numbers following SemVer
- Creates annotated Git tags
- Generates comprehensive release notes from commit history
- Categorizes changes (features, fixes, docs, config)
- Creates GitHub release with infrastructure status
- Includes service URLs and architecture highlights
- Provides deployment and verification steps

**Prerequisites**:
- GitHub CLI installed (`brew install gh`)
- Authenticated with GitHub (`gh auth login`)
- Admin permissions on the repository
- On main branch with latest changes

## Future Tools

This directory can be extended with additional scripts for:
- Cluster health checks
- Automated deployment scripts
- Infrastructure validation tools
- Backup and restore utilities
