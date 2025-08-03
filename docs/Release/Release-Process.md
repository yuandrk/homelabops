# Release Process

This document outlines the versioning strategy and release process for the homelab infrastructure.

## Versioning Strategy

We follow [Semantic Versioning (SemVer)](https://semver.org/) with the format `vMAJOR.MINOR.PATCH`:

- **MAJOR**: Breaking changes, major infrastructure overhauls
- **MINOR**: New features, services, or significant improvements  
- **PATCH**: Bug fixes, minor configuration changes, documentation updates

### Version Examples

- `v1.0.0` - Initial stable release with K3s cluster
- `v1.1.0` - Added open-webui service with LLM capabilities
- `v1.1.1` - Fixed open-webui storage configuration
- `v2.0.0` - Major upgrade to K3s v1.34 with breaking changes

## Release Types

### Major Release (x.0.0)
**When to use:**
- Breaking changes that require manual intervention
- Major K3s/Kubernetes version upgrades
- Complete infrastructure redesign
- Changes that break existing services

**Examples:**
- Upgrading from K3s v1.x to v2.x
- Migrating from single-node to multi-node cluster
- Changing container runtime (Docker → containerd)

### Minor Release (x.y.0)  
**When to use:**
- New services or applications
- Major feature additions
- Infrastructure improvements
- New external integrations

**Examples:**
- Adding new services (open-webui, monitoring stack)
- Implementing Cloudflare tunnels
- Adding multi-architecture support
- New GitOps workflows

### Patch Release (x.y.z)
**When to use:**
- Bug fixes and hotfixes
- Configuration corrections
- Documentation updates
- Security patches

**Examples:**
- Fixing service connectivity issues
- Correcting resource limits
- Updating documentation
- Security configuration updates

## Release Process

### Automated Release Creation

Use the provided script to create releases:

```bash
# Auto-generate next version (minor release)
./tools/create-release.sh

# Specify version and type
./tools/create-release.sh v1.2.0 minor

# Create patch release
./tools/create-release.sh v1.1.1 patch

# Create major release
./tools/create-release.sh v2.0.0 major
```

### Manual Release Process

If you prefer manual control:

1. **Prepare Release**
   ```bash
   # Ensure main branch is up to date
   git checkout main
   git pull origin main
   
   # Check cluster status
   kubectl get nodes
   kubectl get pods -A
   ```

2. **Create Tag**
   ```bash
   # Create annotated tag
   git tag -a v1.1.0 -m "Release v1.1.0: Add open-webui LLM service"
   
   # Push tag
   git push origin v1.1.0
   ```

3. **Create GitHub Release**
   ```bash
   # Create release with auto-generated notes
   gh release create v1.1.0 --generate-notes
   
   # Or create with custom notes
   gh release create v1.1.0 --title "Release v1.1.0" --notes-file RELEASE_NOTES.md
   ```

## Release Notes Template

Each release should include:

```markdown
# Release v1.1.0

## 🏗️ Infrastructure Status
- K3s Cluster: 3-node cluster operational
- FluxCD: v2.6.0 GitOps deployment
- Services: [list active services]

## 🔧 What's Changed
### ✨ New Features
- Added open-webui LLM interface (chat.yuandrk.net)
- Implemented node affinity for amd64 workloads

### 🐛 Bug Fixes  
- Fixed PVC node affinity issues
- Resolved ingress configuration

### ⚙️ Configuration Changes
- Updated storage allocation to 50Gi
- Enhanced branch protection rules

## 🚀 Services & Access
- 🤖 Open-WebUI: https://chat.yuandrk.net
- 🛡️ Pi-hole: https://pihole.yuandrk.net
- 💰 Budget App: https://budget.yuandrk.net

## 📊 Architecture Highlights
- Multi-architecture support (amd64 + arm64)
- Secure Cloudflare tunnel access
- GitOps automation with FluxCD

## 🛠️ Deployment
This release is automatically deployed via FluxCD.
```

## Release Checklist

### Pre-Release
- [ ] All services are operational
- [ ] Documentation is up to date  
- [ ] Cluster health check passed
- [ ] Branch protection rules are in place
- [ ] No failing GitOps reconciliations

### Release Creation
- [ ] Version follows SemVer conventions
- [ ] Release notes are comprehensive
- [ ] Tag is properly annotated
- [ ] GitHub release is created
- [ ] Release is marked as latest (if applicable)

### Post-Release
- [ ] FluxCD deployment completed successfully
- [ ] All services remain operational
- [ ] External access is working
- [ ] Documentation reflects current state
- [ ] CHANGELOG.md is updated (if maintained)

## Emergency Hotfix Process

For critical issues requiring immediate fixes:

1. **Create hotfix branch from latest release tag**
   ```bash
   git checkout -b hotfix/v1.1.1 v1.1.0
   ```

2. **Apply minimal fix**
   ```bash
   # Make necessary changes
   git commit -m "fix: critical service connectivity issue"
   ```

3. **Create patch release**
   ```bash
   ./tools/create-release.sh v1.1.1 patch
   ```

4. **Merge back to main**
   ```bash
   git checkout main
   git merge hotfix/v1.1.1
   git push origin main
   ```

## Rollback Process

If a release causes issues:

1. **Identify last stable release**
   ```bash
   gh release list
   ```

2. **Rollback GitOps to previous tag**
   ```bash
   # Update FluxCD to target previous tag
   # This depends on your GitOps configuration
   ```

3. **Create rollback release**
   ```bash
   ./tools/create-release.sh v1.1.2 patch
   # Include rollback information in release notes
   ```

## Best Practices

### Release Timing
- **Minor releases**: Every 2-4 weeks
- **Patch releases**: As needed for fixes
- **Major releases**: Every 3-6 months

### Testing
- Test all services after deployment
- Verify external access via Cloudflare tunnels
- Check resource utilization and performance
- Validate backup and monitoring systems

### Communication
- Use clear, descriptive release notes
- Include migration steps for breaking changes
- Document any manual intervention required
- Update relevant documentation

### Automation
- Leverage the release script for consistency
- Use GitHub Actions for additional automation (optional)
- Integrate with monitoring for release success/failure alerts
- Consider automated rollback triggers
