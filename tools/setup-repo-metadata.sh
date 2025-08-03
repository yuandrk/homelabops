#!/bin/bash
# Setup GitHub repository metadata (About section and Topics)
# Run this script after authenticating with GitHub CLI: gh auth login

set -e

echo "Setting up GitHub repository metadata..."

# First, authenticate if not already done
if ! gh auth status >/dev/null 2>&1; then
    echo "Please authenticate with GitHub CLI first:"
    echo "gh auth login"
    exit 1
fi

# Get repository info
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
echo "Repository: $REPO"

# Set repository description
echo "Setting repository description..."
gh repo edit \
    --description "GitOps homelab infrastructure with K3s, FluxCD, Terraform, and Ansible. Features multi-arch cluster, Cloudflare tunnels, and LLM services." \
    --homepage "https://chat.yuandrk.net"

# Add repository topics
echo "Adding repository topics..."
gh repo edit \
    --add-topic "homelab" \
    --add-topic "gitops" \
    --add-topic "k3s" \
    --add-topic "kubernetes" \
    --add-topic "fluxcd" \
    --add-topic "terraform" \
    --add-topic "ansible" \
    --add-topic "cloudflare-tunnel" \
    --add-topic "infrastructure-as-code" \
    --add-topic "raspberry-pi" \
    --add-topic "multi-arch" \
    --add-topic "llm" \
    --add-topic "open-webui" \
    --add-topic "self-hosted" \
    --add-topic "pihole" \
    --add-topic "mermaid-diagrams"

echo "✅ Repository metadata updated successfully!"
echo ""
echo "📋 Description: GitOps homelab infrastructure with K3s, FluxCD, Terraform, and Ansible"
echo "🏠 Homepage: https://chat.yuandrk.net"
echo ""
echo "🏷️ Topics added:"
echo "  - homelab, gitops, k3s, kubernetes"
echo "  - fluxcd, terraform, ansible"
echo "  - cloudflare-tunnel, infrastructure-as-code"
echo "  - raspberry-pi, multi-arch"
echo "  - llm, open-webui, self-hosted"
echo "  - pihole, mermaid-diagrams"
echo ""
echo "🎉 Your repository now has proper About section and Topics!"
