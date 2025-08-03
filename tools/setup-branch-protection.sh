#!/bin/bash
# Setup branch protection rules for dev branch
# Run this script after authenticating with GitHub CLI: gh auth login

set -e

echo "Setting up branch protection rules for dev branch..."

# First, authenticate if not already done
if ! gh auth status >/dev/null 2>&1; then
    echo "Please authenticate with GitHub CLI first:"
    echo "gh auth login"
    exit 1
fi

# Get repository info
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
echo "Repository: $REPO"

# Create branch protection rule for dev branch
echo "Creating branch protection rule for dev branch..."

gh api repos/"$REPO"/branches/dev/protection \
    --method PUT \
    --field required_status_checks=null \
    --field enforce_admins=true \
    --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true,"require_code_owner_reviews":false}' \
    --field restrictions=null \
    --field allow_force_pushes=false \
    --field allow_deletions=false

echo "✅ Branch protection rules applied to dev branch:"
echo "  - Require pull request reviews (1 approval required)"
echo "  - Dismiss stale reviews when new commits are pushed"
echo "  - Enforce all configured restrictions for administrators"
echo "  - Prevent force pushes"
echo "  - Prevent branch deletion"

# Display current protection status
echo ""
echo "Current protection status for dev branch:"
gh api repos/"$REPO"/branches/dev/protection --jq '
{
  "required_status_checks": .required_status_checks,
  "enforce_admins": .enforce_admins.enabled,
  "required_pull_request_reviews": .required_pull_request_reviews,
  "allow_force_pushes": .allow_force_pushes.enabled,
  "allow_deletions": .allow_deletions.enabled
}'

echo ""
echo "🎉 Branch protection setup complete!"
echo "To work with the protected dev branch:"
echo "  1. Create feature branches from dev: git checkout -b feature/new-feature dev"
echo "  2. Push feature branch: git push -u origin feature/new-feature"
echo "  3. Create PR to dev branch via GitHub web interface"
echo "  4. Merge after review approval"
