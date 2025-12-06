# HomeLab GitOps

[![Kubernetes](https://img.shields.io/badge/k3s-v1.33.3-green)](https://k3s.io/)
[![FluxCD](https://img.shields.io/badge/FluxCD-v2.6.0-blue)](https://fluxcd.io/)
[![Ansible](https://img.shields.io/badge/Ansible-automated-red)](https://ansible.com/)
[![Terraform](https://img.shields.io/badge/Terraform-AWS%20%2B%20Cloudflare-purple)](https://terraform.io/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Operational-brightgreen)]()

My personal homelab infrastructure running K3s cluster with automated deployment and management.

## 📋 Overview

This repository contains Infrastructure as Code and documentation for my homelab K3s cluster with GitOps automation. Infrastructure is managed via Ansible automation, Terraform for cloud resources, and FluxCD for continuous deployment.

## 🏗️ Architecture Overview

![HomeLab Architecture](docs/Architecture/architecture_overview.png)

### Infrastructure Details

- **Cluster**: 4-node K3s cluster (1 master + 3 workers) on Ubuntu 24.04 LTS
- **GitOps**: FluxCD v2.6.0 with automated deployment from Git
- **Automation**: Ansible for node configuration and cluster deployment
- **Networking**: Dual network setup (10.10.0.0/24 LAN + 192.168.1.0/24 Wi-Fi)
- **External Access**: Cloudflare Tunnels + Traefik ingress (9 public services)
- **DNS**: Pi-hole (host) + CoreDNS (K3s)
- **Database**: PostgreSQL 15 on k3s-worker3 (Native)
- **GPU**: NVIDIA GeForce MX130 on k3s-worker3 (Ollama LLM workloads)
- **Infrastructure**: Terraform for AWS backend + Cloudflare tunnels
- **Storage**: 76Gi total (local-path provisioner)

## 📁 Repository Structure

```
homelabops/
├── .github/workflows/    # CI/CD pipelines (planned)
├── ansible/              # Node configuration and K3s deployment
│   ├── inventory/        # Host inventory and group variables
│   ├── playbooks/        # Ansible playbooks
│   └── roles/            # Reusable roles (ssh_hardening, k3s_install, etc.)
├── apps/                 # Application deployments (FluxCD HelmReleases)
├── clusters/             # FluxCD cluster configurations
├── docs/                 # 📚 Comprehensive documentation
│   ├── Ansible/          # Ansible automation guides
│   ├── Database/         # PostgreSQL setup and management
│   ├── DevOps-Workflow/  # Git workflow, pre-commit, CI/CD
│   ├── K3s/              # K3s deployment and troubleshooting
│   ├── Network/          # Network architecture and performance
│   ├── Planning/         # Future deployment plans
│   └── Terraform/        # Infrastructure as Code documentation
├── infrastructure/       # Core infrastructure configs
├── monitoring/           # Observability stack (planned)
├── scripts/              # Automation and utility scripts
├── terraform/            # Infrastructure as Code
│   ├── bootstrap/        # AWS S3 + DynamoDB backend
│   ├── cloudflare/       # DNS and tunnel management
│   ├── fluxcd/           # FluxCD GitOps deployment
│   └── modules/          # Reusable Terraform modules
└── tools/                # Development tools
```

## 🚀 Quick Start

### Prerequisites
- 3 Ubuntu 24.04 LTS nodes with SSH key access
- Ansible installed locally
- Terraform >= 1.8.0
- AWS CLI configured for backend
- Cloudflare API token

### Deploy K3s Cluster
```bash
# Test connectivity
ansible -i ansible/inventory/hosts.ini all -m ping

# Deploy complete cluster
ANSIBLE_BECOME_PASS=password ansible-playbook \
  -i ansible/inventory/hosts.ini \
  ansible/playbooks/cluster_bootstrap.yaml

# Verify cluster
kubectl --kubeconfig=terraform/kube/kubeconfig get nodes
```

### Manage Infrastructure
```bash
# Deploy Cloudflare tunnels
cd terraform/cloudflare
terraform init && terraform apply

# Deploy FluxCD GitOps
cd terraform/fluxcd
terraform init && terraform apply

# Get tunnel token
terraform output -raw tunnel_token
```

## 📊 Current Status

### Cluster Health ✅
- **4-node K3s cluster**: All nodes operational (1 master + 3 workers)
- **Version**: v1.33.3-v1.33.5+k3s1 (minor version skew on workers)
- **Network**: Dual setup with gigabit LAN + Wi-Fi fallback
- **External Access**: 9 services via Cloudflare Tunnels
- **GPU**: NVIDIA GeForce MX130 on k3s-worker3 (CUDA 12.2)

### Services Running
- **FluxCD v2.6.0**: GitOps continuous deployment
- **open-webui**: LLM interface with Ollama integration (`chat.yuandrk.net`)
- **Pi-hole**: DNS server with ad-blocking (`pihole.yuandrk.net`)
- **PostgreSQL**: Database on k3s-worker3 (Native)
- **Traefik**: K3s ingress controller
- **CoreDNS**: K3s cluster DNS

### GitOps Status ✅
- **FluxCD**: Deployed and monitoring Git repository
- **Applications**: Clean slate with only open-webui active
- **Repository**: Connected via SSH deploy key
- **Sync**: Automatic reconciliation every 1 minute
- **Webhook**: External trigger available (`flux-webhook.yuandrk.net`)

## 📚 Documentation

Comprehensive documentation is available in the [`docs/`](docs/) directory:

- **[Infrastructure Diagrams](docs/Architecture/Infrastructure-Diagrams.md)** - 🎨 Mermaid architecture diagrams
- **[Network Architecture](docs/Network/Network-Architecture.md)** - Complete network setup and topology
- **[Release Process](docs/Release/Release-Process.md)** - 🏷️ Versioning and release management
- **[K3s Deployment](docs/K3s/)** - Cluster deployment and troubleshooting guides  
- **[Ansible Automation](docs/Ansible/Ansible-overview.md)** - Infrastructure automation
- **[FluxCD GitOps](docs/FluxCD/)** - GitOps deployment and troubleshooting
- **[FluxCD Health Monitoring](docs/FluxCD/FluxCD-Health-Monitoring.md)** - 🔍 System health checks and monitoring
- **[Database Setup](docs/Database/)** - PostgreSQL configuration
- **[Terraform Infrastructure](docs/Terraform/)** - Cloud infrastructure management

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏷️ Topics

`homelab` `gitops` `k3s` `kubernetes` `fluxcd` `terraform` `ansible` `cloudflare-tunnel` `infrastructure-as-code` `raspberry-pi` `multi-arch` `llm` `open-webui` `self-hosted` `pihole` `mermaid-diagrams`

---

*This homelab follows GitOps principles with infrastructure as code and automated deployment.*
