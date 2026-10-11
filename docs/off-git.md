# Outside git

Flux rebuilds everything in the cluster from this repository. This page lists what it cannot:
state on the hosts and in external accounts. If a disk or an account is lost, this is the list
of things to redo by hand. Ansible used to cover part of the host layer. It was removed in
`5cc1b2a` (bootstrap-only, and its `k3s_install` role would have wiped the cluster on any
config change), so since 2026-08-01 node changes are made directly on the hosts and recorded
here.

The **Copy** column says where that state survives a dead disk: `restic` means the nightly
backups ([backup.md](backup.md)), `1Password` means vault `homelab`, and `doc` means only the
description in these docs. **Not recorded** marks values nobody has written down yet. Fill
them in from the live host the next time you are on it.

## k3s-master

| What | Where | Copy |
|------|-------|------|
| k3s server flags `--cluster-cidr`, `--service-cidr` and one `--tls-san` | the k3s systemd unit. The install script drops them on a re-run, see [runbooks/upgrade-k3s.md](runbooks/upgrade-k3s.md) | **Not recorded** (the CIDRs in use are `10.42.0.0/16` and `10.43.0.0/16`) |
| k3s server config, including the Okta OIDC flags of the API server | `/etc/rancher/k3s/config.yaml` | **Not recorded** |
| Cluster datastore and join token | `/var/lib/rancher/k3s/server/` | none. Git recreates the objects. A new server means a new token, and every worker has to re-join |
| Important data: Immich library, ActualBudget | `/srv/data/{immich,actualbudget}` | restic, local and B2 |
| local-path volumes: n8n, Kite, qBittorrent config | `/var/lib/rancher/k3s/storage/pvc-*` | restic. A new cluster gives them new names, see [the rebuild runbook](runbooks/rebuild-k3s-master.md#2-data-before-anything-writes-to-it) |
| NFS export of the Immich library to k3s-worker3 | `/etc/exports.d/immich.exports` | doc: [backup.md](backup.md#where-the-data-lives) |
| restic: env files, password file, four timers, SSH key and alias for worker1 | `/etc/restic/`, `restic-*.{service,timer}`, `/root/.ssh/` | password and B2 key in 1Password, the rest is described in [backup.md](backup.md) |
| Tailscale node and subnet router for `10.10.0.0/24`, address `100.96.117.64` | `tailscaled` | doc: [network-architecture.md](network-architecture.md#tailscale). The address is also hardcoded in Terraform (`internal_ingress_ip`) |
| Hermes agent and dashboard | user units `hermes-gateway.service` and `hermes-dashboard.service` with drop-in `proxy.conf`. Its home is `~/.hermes/` (`config.yaml`, `kube-sandbox.conf`, `sandbox/run-job.sh`) | `kube-sandbox.conf` in 1Password. `config.yaml` exists only as `.bak-*` files next to itself, on the same disk, and **is not in restic** |
| Admin kubeconfig copy | `~/.kube/config`, a copy of `k3s.yaml` (`system:masters`) | regenerated from the server |
| Obsidian vault backup | user units `vault-backup.*`, key in `~/.restic-env` | goes to B2 bucket `obsidian-backup-yuandrk` |
| Media | `/srv/media` (qBittorrent downloads, old Jellyfin files) | none, by design: re-downloadable |

## Every node

| What | Where | Copy |
|------|-------|------|
| SSH on port 2222, keys only | sshd config | doc |
| DNS: systemd-resolved to 1.1.1.1 / 8.8.8.8, node names in `/etc/hosts` | `/etc/systemd/resolved.conf.d/homelab.conf`, `/etc/hosts` | doc: [network-architecture.md](network-architecture.md#dns-configuration) |
| Firewall | UFW disabled | doc |
| k3s binary and version | `/usr/local/bin/k3s`. The workers' agent config holds the server URL `10.10.0.1:6443` and the join token | **Not recorded**: where the workers keep the token |

## k3s-worker1

| What | Where | Copy |
|------|-------|------|
| The disposable taint `homelab.yuandrk.net/disposable=true:NoSchedule` | the Node object. Git only has the tolerations for it | **Not recorded**: whether it was set with `kubectl taint` (then it is lost when the node re-registers) or through `node-taint` in the agent's config |
| restic repository: user `restic`, SFTP-only key | `/srv/backup/restic`, `/srv/backup/.ssh/authorized_keys` | doc: [backup.md](backup.md#local-copy-k3s-worker1) |

## k3s-worker3

| What | Where | Copy |
|------|-------|------|
| PostgreSQL, native rather than in k3s. Databases for Immich and n8n, read by Grafana's datasource | `:5432` | Immich's database goes into Immich's own dumps in the library (restic). **n8n's database has no backup.** Roles and `pg_hba.conf` are **not recorded** |
| local-path volumes: Fleet's MySQL (8Gi), Prometheus, the Immich ML cache | `/var/lib/rancher/k3s/storage/` | **none**: restic runs on k3s-master only. Fleet's device inventory and its first-run settings (server URL, admin) live in that MySQL |
| Intel iGPU for Immich's hardware transcoding | `/dev/dri`. The render group GID `993` is hardcoded in the Immich HelmRelease | doc. Update `apps/immich` if a reinstall changes the GID |
| NVIDIA driver 535 / CUDA 12.2 for the MX130 | host packages | unused since the device plugin was removed in `db40da1`. Revert that commit to bring GPU scheduling back |
| Internet access | worker3 has no Wi-Fi interface | **Not recorded**: the route it uses to reach the internet, presumably through k3s-master |

## External accounts

| Account | What lives there | Recreated from |
|---------|------------------|----------------|
| Cloudflare | zone `yuandrk.net`, tunnel `homeserver`, the proxied catch-all `*.yuandrk.net`, the API token CI uses | Terraform recreates the tunnel's ingress rules, the per-app CNAMEs and `*.home`. The tunnel itself and the catch-all record were made by hand |
| Okta (`okta.yuandrk.net`) | the apps for the k3s API/Headlamp, Kite and the Hermes dashboard, the groups and the app assignments | [access.md](access.md) describes each app. Nothing is exported |
| 1Password | vault `homelab`, the operator's service account | [secrets.md](secrets.md) |
| GitHub | Actions secrets `AWS_ROLE_ARN` and `CLOUDFLARE_*`, environment `homelab` with its approval gate, Flux's deploy key, the Renovate app | [terraform-guide.md](terraform-guide.md) |
| AWS | S3 state bucket, GitHub OIDC provider and role | Terraform stacks `aws-bootstrap` and `aws-oidc`, applied once from a laptop, not by CI. `aws-oidc` has no backend, so its state and its `terraform.tfvars` (the live trust patterns) exist only where it was applied |
| Backblaze B2 | buckets `homelab-backup-yuandrk` and `obsidian-backup-yuandrk`, bucket-scoped keys, the lifecycle rule | [backup.md](backup.md#offsite-copy-backblaze-b2) |
| Tailscale | tailnet `tail1fbf9e.ts.net`, approval of k3s-master's subnet route | [network-architecture.md](network-architecture.md#tailscale) |

## Open questions

- **The Flux webhook.** `flux-webhook.yuandrk.net` routes to `webhook-receiver` in
  `flux-system`, but no `Receiver` resource has ever been in git. Either one was created by
  hand, and then it and its token Secret belong in the tables above, or GitHub's calls end in a
  404 and Flux runs on its 1-minute poll alone. Check with `kubectl get receivers -A`.
- Every **Not recorded** cell above.
