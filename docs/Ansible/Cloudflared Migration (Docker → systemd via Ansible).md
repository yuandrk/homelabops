
## Overview
Moves existing cloudflared tunnel from Docker container to a systemd service on **k3s-master**, managed with Ansible, using Cloudflare Zero‑Trust **token** mode.
- **Why**: Faster boot, no Docker dependency, aligns with future k3s/Helm strategy.
- **Mode**: Token‑based (`cloudflared service install <TOKEN>`). Ingress rules configured in Cloudflare UI.
## Prerequisites

|Host|OS/Arch|Notes|
|---|---|---|
|`k3s-master`|Ubuntu 24.04 amd64|Pi‑hole runs bare‑metal; master node for k3s|
|Ansible controller|ansible-core 2.18|`vault_password_file` configured|

- Cloudflare Tunnel already exists; token copied to Ansible Vault.
## Repository structure (relevant parts)

```
ansible/
 ├── inventory/
 │   ├── production.yaml
 │   └── group_vars/
 │       └── masters/
 │           ├── cloudflared.yaml          # non‑secret vars
 │           └── vault_cloudflared.yaml    # encrypted token
 ├── roles/
 │   └── cloudflared/
 │       ├── defaults/main.yaml
 │       ├── tasks/main.yaml
 │       ├── handlers/main.yaml
 │       └── templates/config.yaml.j2
 └── playbooks/
     └── cloudflared.yaml
```
## Role: `roles/cloudflared`

1. Add Cloudflare GPG key (`get_url`)
2. Add APT repo `pkg.cloudflare.com/cloudflared any main`
3. Install fixed version `cloudflared={{ cloudflared_version }}`
4. `cloudflared service install {{ cloudflared_token }}` (creates systemd unit)
5. Ensure `/etc/cloudflared` exists
6. Deploy optional `config.yml` (ignored in token mode)
7. Enable & start service; handler restarts on config change

### Defaults (`defaults/main.yaml`)

```yaml
cloudflared_version: "2025.7.0-1"
cloudflared_auto_upgrade: false
```
### Non‑secret vars (`group_vars/masters/cloudflared.yaml`)

```yaml
cloudflared_tunnel_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
cloudflared_hostname: "pihole.yuandrk.net"
cloudflared_service_port: 80
cloudflared_metrics: "127.0.0.1:9469"
cloudflared_no_autoupdate: true
```
### Secret token (vault‑encrypted)
`group_vars/masters/vault_cloudflared.yaml`
```yaml
encrypted with ansible-vault
```
## Playbook
`playbooks/cloudflared.yaml`
```yaml
- name: Install Cloudflared on master
  hosts: masters
  become: true
  roles:
    - cloudflared
```
Run:

```bash
ansible-playbook playbooks/cloudflared.yaml -K -l k3s-master
```
## Cloudflare Dashboard steps

1. Zero Trust → Networks → **Tunnels** → select tunnel.
2. **Public Hostnames → Add a hostname**:
    - `Hostname`: `pihole.yuandrk.net`
    - `Service`: `http://127.0.0.1:80`
3. Wait for automatic config push (check `journalctl -u cloudflared -f`).
## Validation checklist

- `systemctl status cloudflared` shows _active (running)_ with `--token …`.
- Dashboard tunnel status: **Healthy**.
- Browser access to `https://pihole.yuandrk.net/admin` succeeds.
- Metrics endpoint available at `curl http://127.0.0.1:9469/metrics`.
## Future work (GitOps path)

|Milestone|Action|
|---|---|
|**Helm tunnel**|Deploy `cloudflared` Helm chart in k3s for cluster services.|
|**Credentials mode**|Switch to `tunnel run` with credentials JSON + `config.yml` managed by Ansible.|
|**Ingress-as‑Code**|Maintain all hostnames in repo; update via playbook, not UI.|

---
**Last updated:** 2025‑07‑20
