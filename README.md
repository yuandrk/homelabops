# HomeLab GitOps

[![FluxCD](https://img.shields.io/badge/GitOps-FluxCD-blue)](https://fluxcd.io/)
[![Kubernetes](https://img.shields.io/badge/k3s-v1.33-green)](https://k3s.io/)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

My personal homelab running on K3s with GitOps via FluxCD.

## 📋 Overview

This repository contains the declarative configuration for my homelab Kubernetes cluster. Changes pushed to `main` are automatically deployed by FluxCD.

## 🏗️ Architecture

- **Cluster**: K3s on Ubuntu 24.04 LTS
- **GitOps**: FluxCD v2
- **Networking**: Cloudflare Tunnels + Traefik
- **Storage**: Local-path provisioner
- **Secrets**: Sealed Secrets / SOPS

## 📁 Repository Structure

- `ansible/` - Node configuration management
- `clusters/` - Kubernetes manifests organized by cluster
- `terraform/` - Infrastructure as code for cloud resources
- `scripts/` - Automation and utility scripts
- `docs/` - Documentation and runbooks
