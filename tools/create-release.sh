#!/bin/bash
# Create a new release with tag for homelab infrastructure
# Usage: ./tools/create-release.sh [version] [type]
# Example: ./tools/create-release.sh v1.0.0 major

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERSION=${1}
RELEASE_TYPE=${2:-minor}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if gh CLI is available and authenticated
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed. Install with: brew install gh"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    print_error "Please authenticate with GitHub CLI first: gh auth login"
    exit 1
fi

# Get repository info
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
print_status "Repository: $REPO"

# If no version provided, auto-generate based on latest tag
if [ -z "$VERSION" ]; then
    print_status "Auto-generating version number..."
    
    # Get latest tag
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    print_status "Latest tag: $LATEST_TAG"
    
    # Parse version numbers
    if [[ $LATEST_TAG =~ v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        MAJOR=${BASH_REMATCH[1]}
        MINOR=${BASH_REMATCH[2]}
        PATCH=${BASH_REMATCH[3]}
    else
        MAJOR=0
        MINOR=0
        PATCH=0
    fi
    
    # Increment based on release type
    case $RELEASE_TYPE in
        major)
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            ;;
        minor)
            MINOR=$((MINOR + 1))
            PATCH=0
            ;;
        patch)
            PATCH=$((PATCH + 1))
            ;;
        *)
            print_error "Invalid release type: $RELEASE_TYPE. Use: major, minor, or patch"
            exit 1
            ;;
    esac
    
    VERSION="v${MAJOR}.${MINOR}.${PATCH}"
fi

print_status "Creating release: $VERSION"

# Check if tag already exists
if git tag -l | grep -q "^${VERSION}$"; then
    print_error "Tag $VERSION already exists!"
    exit 1
fi

# Ensure we're on main branch and up to date
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    print_warning "Not on main branch. Switching to main..."
    git checkout main
fi

print_status "Pulling latest changes..."
git pull origin main

# Generate release notes based on commits since last tag
print_status "Generating release notes..."

if [ "$LATEST_TAG" != "v0.0.0" ]; then
    COMMIT_RANGE="${LATEST_TAG}..HEAD"
else
    COMMIT_RANGE="HEAD"
fi

# Get commits and categorize them
FEATURES=$(git log $COMMIT_RANGE --oneline --grep="^feat" --grep="^feature" | sed 's/^[a-f0-9]* /- /')
FIXES=$(git log $COMMIT_RANGE --oneline --grep="^fix" | sed 's/^[a-f0-9]* /- /')
DOCS=$(git log $COMMIT_RANGE --oneline --grep="^docs" | sed 's/^[a-f0-9]* /- /')
CONFIG=$(git log $COMMIT_RANGE --oneline --grep="^config" | sed 's/^[a-f0-9]* /- /')
OTHER=$(git log $COMMIT_RANGE --oneline --invert-grep --grep="^feat" --grep="^fix" --grep="^docs" --grep="^config" | sed 's/^[a-f0-9]* /- /')

# Create release notes
RELEASE_NOTES_FILE="/tmp/release_notes_${VERSION}.md"
cat > "$RELEASE_NOTES_FILE" << EOF
# Release $VERSION

This release includes infrastructure improvements, new services, and configuration updates for the homelab GitOps setup.

## 🏗️ Infrastructure Status
- **K3s Cluster**: 3-node cluster (1 amd64 master + 2 arm64 workers)
- **FluxCD**: v2.6.0 GitOps deployment
- **Services**: open-webui (chat.yuandrk.net), Pi-hole, PostgreSQL
- **External Access**: Cloudflare tunnels with secure HTTPS

## 🔧 What's Changed

EOF

if [ -n "$FEATURES" ]; then
    echo -e "### ✨ New Features\n$FEATURES\n" >> "$RELEASE_NOTES_FILE"
fi

if [ -n "$FIXES" ]; then
    echo -e "### 🐛 Bug Fixes\n$FIXES\n" >> "$RELEASE_NOTES_FILE"
fi

if [ -n "$CONFIG" ]; then
    echo -e "### ⚙️ Configuration Changes\n$CONFIG\n" >> "$RELEASE_NOTES_FILE"
fi

if [ -n "$DOCS" ]; then
    echo -e "### 📚 Documentation\n$DOCS\n" >> "$RELEASE_NOTES_FILE"
fi

if [ -n "$OTHER" ]; then
    echo -e "### 🔄 Other Changes\n$OTHER\n" >> "$RELEASE_NOTES_FILE"
fi

cat >> "$RELEASE_NOTES_FILE" << EOF
## 🚀 Services & Access

- **🤖 Open-WebUI**: https://chat.yuandrk.net (LLM interface)
- **🛡️ Pi-hole**: https://pihole.yuandrk.net (DNS ad-blocking)  
- **💰 Budget App**: https://budget.yuandrk.net
- **🔗 FluxCD Webhook**: https://flux-webhook.yuandrk.net

## 📊 Architecture Highlights

- Multi-architecture cluster (amd64 + arm64)
- GitOps with FluxCD v2.6.0
- Infrastructure as Code (Terraform + Ansible)
- Secure external access via Cloudflare tunnels
- Comprehensive monitoring and documentation

## 🛠️ Deployment

This release is automatically deployed via FluxCD GitOps when merged to main branch.

**Full Changelog**: https://github.com/$REPO/compare/${LATEST_TAG}...${VERSION}
EOF

print_status "Generated release notes:"
cat "$RELEASE_NOTES_FILE"

# Create and push tag
print_status "Creating and pushing tag $VERSION..."
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"

# Create GitHub release
print_status "Creating GitHub release..."
gh release create "$VERSION" \
    --title "Release $VERSION" \
    --notes-file "$RELEASE_NOTES_FILE" \
    --latest

# Clean up
rm "$RELEASE_NOTES_FILE"

print_success "🎉 Release $VERSION created successfully!"
print_success "🌐 View release: https://github.com/$REPO/releases/tag/$VERSION"

# Display next steps
echo ""
print_status "📋 Next steps:"
echo "  1. FluxCD will automatically deploy this release"
echo "  2. Monitor deployment: kubectl get pods -A"  
echo "  3. Verify services are operational"
echo "  4. Update any dependent systems if needed"
