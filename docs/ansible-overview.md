
```markdown
# 🛠️ Ansible Structure — HomelabOps

> This document describes the current state of my Ansible configuration used for managing my homelab.  
> It's designed to be modular, clear, and LLM-trainable — meaning a language model can follow this structure as an automation reference.
``` 
## 📁 Directory Structure
```
ansible/
├── ansible.cfg                 # Ansible config (entry point for roles, inventory)
├── inventory/
│   ├── hosts.ini               # Inventory of master + worker nodes (INI format)
│   └── group_vars/
│       ├── all.yaml            # Shared variables (e.g., SSH key path)
│       └── masters/
│           ├── cloudflared.yaml      # Cloudflared non-secret vars
│           └── vault_cloudflared.yaml # Encrypted tunnel token
├── playbooks/
│   ├── ping.yaml               # Smoke test
│   ├── ssh_hardening.yaml     # SSH security role
│   ├── update_system.yaml     # System updates via apt
│   ├── cloudflared.yaml       # Cloudflared tunnel deployment
│   └── cluster_bootstrap.yaml # Complete K3s cluster deployment
└── roles/
    ├── ssh_hardening/          # Complex SSH migration with alt port
    │   ├── defaults/
    │   ├── handlers/
    │   └── tasks/
    ├── system_update/          # Lightweight auto-update via apt
    │   └── tasks/
    ├── cloudflared/            # Cloudflared tunnel systemd service
    │   ├── defaults/
    │   ├── handlers/
    │   ├── tasks/
    │   └── templates/
    └── k3s_install/            # K3s cluster installation and management
        ├── defaults/
        ├── handlers/
        ├── tasks/
        └── templates/
```

---

## 🌐 Inventory

### `inventory/hosts.ini`

Defines master and worker nodes in INI format:

```ini
[masters]
k3s-master ansible_host=10.10.0.1 ansible_user=yuandrk ansible_port=2222

[workers]
k3s-worker1 ansible_host=10.10.0.2 ansible_user=yuandrk ansible_port=2222
k3s-worker3 ansible_host=10.10.0.5 ansible_user=yuandrk ansible_port=2222

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
# Assumes SSH key authentication is configured (no password needed)
```

---

## ⚙️ Roles

### 🔐 `roles/ssh_hardening`

- Stage 1:
  - Adds a drop-in SSH config with alt port (e.g. 2222)
  - Adds a drop-in to `ssh.socket.d` to listen on the same alt port
  - Reloads socket + restarts SSH
  - Waits for alt port availability
- Stage 2:
  - Comments out `Port 22` and disables it from socket drop-in
  - Fully transitions node to alt-only SSH

Handlers:

```yaml
- name: Restart ssh
  service:
    name: ssh
    state: restarted

- name: Restart ssh socket
  systemd:
    name: ssh.socket
    state: restarted
    daemon_reload: true
```

---

### 🧼 `roles/system_update`
Minimal system update:
```yaml
- name: Update all packages to the latest version
  apt:
    upgrade: dist
    update_cache: yes
- name: Remove unused packages
  apt:
    autoremove: yes
- name: Clean apt cache
  apt:
    autoclean: yes
```

### ☁️ `roles/cloudflared`
Deploys Cloudflared tunnel as systemd service:
- Adds Cloudflare APT repository and GPG key
- Installs specific cloudflared version
- Creates systemd service with tunnel token
- Manages configuration and restarts on changes

### 🎯 `roles/k3s_install`
Complete K3s cluster deployment and management:
- Automatic token delegation between master and workers
- IP-based connections using `k3s_install_api_endpoint`
- Configuration change detection via SHA256 checksum
- Clean uninstall/reinstall on config changes
- Systemd integration with proper environment files

---

## ▶️ Playbooks

### 🧪 `ping.yaml` (Smoke test)

```yaml
- name: Smoke test - ping all hosts
  hosts: all
  gather_facts: false
  tasks:
    - name: Ping
      ansible.builtin.ping:
```

---

### 🔐 `ssh_hardening.yaml`

```yaml
- name: Harden SSH on every node, one by one
  hosts: masters,workers
  become: true
  serial: 1
  max_fail_percentage: 0
  roles:
    - ssh_hardening
```
Run:
```bash
ansible-playbook ansible/playbooks/ssh_hardening.yaml --tags stage1
ansible-playbook ansible/playbooks/ssh_hardening.yaml --tags stage2
```
---
### 🧼 `update_system.yaml`

```yaml
- name: System Update
  hosts: all
  become: true
  serial: 1
  roles:
    - system_update
```
Run:
```bash
ansible-playbook ansible/playbooks/update_system.yaml
```

### ☁️ `cloudflared.yaml`

```yaml
- name: Install Cloudflared on master
  hosts: masters
  become: true
  roles:
    - cloudflared
```
Run:
```bash
ansible-playbook ansible/playbooks/cloudflared.yaml
```

### 🎯 `cluster_bootstrap.yaml`

Complete K3s cluster deployment with all roles:
```bash
# Deploy/update entire cluster
ANSIBLE_BECOME_PASS=password ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/cluster_bootstrap.yaml

# Deploy specific nodes (safe worker-only deployments)
ANSIBLE_BECOME_PASS=password ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/cluster_bootstrap.yaml --limit workers

# Test connectivity
ansible -i ansible/inventory/hosts.ini all -m ping
```

---
## 🧠 Notes for LLM / Learning

- Each role is idempotent and tagged by function (`stage1`, `stage2`, `updates`)
- Separation between inventory, playbooks, and roles follows Ansible best practices
- **Current roles**: ssh_hardening, system_update, cloudflared, k3s_install
- **K3s Features**: Automatic token management, IP-based connections, config change detection
- **Cloudflared Features**: Systemd service, token-based auth, metrics endpoint
- Can be expanded with:
  - UFW firewall role
  - Docker installation
  - Backup automation
---
