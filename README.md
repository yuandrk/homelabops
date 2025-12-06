# HomeLab GitOps

[![Kubernetes](https://img.shields.io/badge/K3s-v1.33-326CE5?logo=kubernetes&logoColor=white)](https://k3s.io/) [![FluxCD](https://img.shields.io/badge/FluxCD-v2.6.0-5468FF?logo=flux&logoColor=white)](https://fluxcd.io/) [![Terraform](https://img.shields.io/badge/Terraform-1.13+-7B42BC?logo=terraform&logoColor=white)](https://terraform.io/) [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE) [![Terraform Plan](https://github.com/yuandrk/homelabops/actions/workflows/terraform-plan.yml/badge.svg)](https://github.com/yuandrk/homelabops/actions/workflows/terraform-plan.yml) [![Terraform Apply](https://github.com/yuandrk/homelabops/actions/workflows/terraform-apply.yml/badge.svg)](https://github.com/yuandrk/homelabops/actions/workflows/terraform-apply.yml)

Production-grade homelab infrastructure running K3s with GitOps automation, Infrastructure as Code, and full observability.

---

## 📑 Table of Contents

- [Overview](#-overview)
- [Tech Stack](#-tech-stack)
- [Architecture](#-architecture)
- [Quick Start](#-quick-start)
- [Services](#-services)
- [Current Status](#-current-status)
- [Repository Structure](#-repository-structure)
- [Documentation](#-documentation)
- [License](#-license)

---

## 📋 Overview

This repository contains Infrastructure as Code and documentation for a 4-node K3s cluster with GitOps automation. Infrastructure is managed via Ansible, Terraform for cloud resources, and FluxCD for continuous deployment.

## 🛠 Tech Stack

| Category | Technologies |
|----------|-------------|
| **Container Orchestration** | ![Kubernetes](https://img.shields.io/badge/K3s-326CE5?logo=kubernetes&logoColor=white) ![Helm](https://img.shields.io/badge/Helm-0F1689?logo=helm&logoColor=white) |
| **GitOps & CD** | ![FluxCD](https://img.shields.io/badge/FluxCD-5468FF?logo=flux&logoColor=white) ![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?logo=github-actions&logoColor=white) |
| **Infrastructure as Code** | ![Terraform](https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white) ![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white) |
| **Monitoring** | ![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?logo=prometheus&logoColor=white) ![Grafana](https://img.shields.io/badge/Grafana-F46800?logo=grafana&logoColor=white) |
| **Networking** | ![Cloudflare](https://img.shields.io/badge/Cloudflare-F38020?logo=cloudflare&logoColor=white) ![Traefik](https://img.shields.io/badge/Traefik-24A1C1?logo=traefikproxy&logoColor=white) |
| **Database** | ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white) |
| **Security** | ![SOPS](https://img.shields.io/badge/SOPS-encrypted-green) ![OIDC](https://img.shields.io/badge/AWS_OIDC-FF9900?logo=amazonaws&logoColor=white) |

## 🏗 Architecture

![HomeLab Architecture](docs/Architecture/architecture_overview.png)

<details>
<summary><b>Infrastructure Details</b></summary>

| Component | Details |
|-----------|---------|
| **Cluster** | 4-node K3s (1 master + 3 workers) on Ubuntu 24.04 LTS |
| **GitOps** | FluxCD v2.6.0 with automatic reconciliation |
| **Networking** | Dual network (10.10.0.0/24 LAN + 192.168.1.0/24 Wi-Fi) |
| **External Access** | Cloudflare Tunnels + Traefik ingress |
| **DNS** | Pi-hole (host) + CoreDNS (cluster) |
| **Database** | PostgreSQL 15 on k3s-worker3 |
| **GPU** | NVIDIA GeForce MX130 (Ollama LLM workloads) |
| **Storage** | 76Gi total (local-path provisioner) |

</details>

## 🚀 Quick Start

**Prerequisites:** `kubectl`, `flux`, `terraform`, `ansible` | Ubuntu 24.04 nodes with SSH access

```bash
# Clone repository
git clone git@github.com:yuandrk/homelabops.git && cd homelabops

# Verify cluster health
kubectl get nodes                          # All nodes Ready
kubectl get kustomizations -n flux-system  # All reconciled
kubectl get helmreleases -A                # All deployed

# Check FluxCD status
flux get all -A
```

📖 **Detailed Guides:** [K3s Deployment](docs/K3s/) · [Ansible](docs/Ansible/Ansible-overview.md) · [Terraform](docs/Terraform/) · [FluxCD](docs/FluxCD/)

## 🌐 Services

| Service | Description | URL |
|---------|-------------|-----|
| **open-webui** | LLM interface with Ollama | `chat.yuandrk.net` |
| **Grafana** | Monitoring dashboards | `grafana.yuandrk.net` |
| **ActualBudget** | Financial management | `budget.yuandrk.net` |
| **Uptime Kuma** | Service monitoring | `uptime.yuandrk.net` |
| **n8n** | Workflow automation | `n8n.yuandrk.net` |
| **pgAdmin** | PostgreSQL admin | `pgadmin.yuandrk.net` |
| **Headlamp** | Kubernetes dashboard | `headlamp.yuandrk.net` |
| **Pi-hole** | DNS + ad-blocking | `pihole.yuandrk.net` |
| **FluxCD** | GitOps webhook | `flux-webhook.yuandrk.net` |

## 📊 Current Status

### Cluster Health ✅

| Component | Status |
|-----------|--------|
| K3s Nodes | 4/4 Ready (v1.33.x) |
| Kustomizations | 6 reconciled |
| HelmReleases | 3 deployed |
| External Services | 9 via Cloudflare Tunnels |

### GitOps ✅
- **Sync**: Automatic reconciliation every 1 minute
- **Repository**: Connected via SSH deploy key
- **Webhook**: External trigger enabled

### Monitoring ✅
- **Prometheus**: 15-day retention, 10Gi storage
- **Grafana**: Flux, node, and cluster dashboards
- **Alerts**: 36 active PrometheusRules

### CI/CD ✅
- **Terraform Plan**: Auto-comment on PRs
- **Terraform Apply**: Auto-deploy with environment protection
- **GitHub OIDC**: Secure AWS authentication
- **Renovate**: Automated dependency updates

## 📁 Repository Structure

```
homelabops/
├── .github/workflows/    # CI/CD (Terraform plan/apply, Renovate)
├── ansible/              # Node configuration and K3s deployment
├── apps/                 # Application deployments (FluxCD)
├── clusters/             # FluxCD cluster configurations
├── docs/                 # Comprehensive documentation
├── infrastructure/       # Core infrastructure + monitoring
├── scripts/              # Automation utilities
├── terraform/            # Infrastructure as Code
│   └── live/homelab/     # AWS OIDC, Cloudflare tunnels
└── tools/                # Development tools
```

## 📚 Documentation

| Topic | Description |
|-------|-------------|
| [Architecture Diagrams](docs/Architecture/Infrastructure-Diagrams.md) | Mermaid infrastructure diagrams |
| [Network Architecture](docs/Network/Network-Architecture.md) | Network topology and setup |
| [K3s Deployment](docs/K3s/) | Cluster deployment guides |
| [FluxCD GitOps](docs/FluxCD/) | GitOps setup and troubleshooting |
| [Monitoring](docs/Monitoring/) | Prometheus/Grafana stack |
| [Terraform](docs/Terraform/) | Cloud infrastructure management |
| [Ansible](docs/Ansible/Ansible-overview.md) | Infrastructure automation |
| [Database](docs/Database/) | PostgreSQL configuration |

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <i>Built with GitOps principles · Infrastructure as Code · Automated deployment</i>
</p>
