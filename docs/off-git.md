# Outside git

Flux rebuilds everything in the cluster from this repository. This page lists what it cannot:
state on the hosts and in external accounts. If a disk or an account is lost, this is the list
of things to redo by hand. Hosts are changed by hand and the changes are recorded here
([why](decisions.md#2026-08-01--hosts-are-changed-by-hand-and-the-changes-are-written-down)).

The **Copy** column says where that state survives a dead disk: `restic` means the nightly
backups ([backup.md](backup.md)), `1Password` means vault `homelab`, and `doc` means only the
description in these docs. **Not recorded** marks values nobody has written down yet. They are
listed under [Unknowns](TODO.md#unknowns), and the [inventory runbook](runbooks/inventory.md)
collects them from the live hosts. Leftovers waiting to be deleted are in
[TODO](TODO.md#cleanup). This page was last checked against the inventory on 2026-10-11.

## k3s-master

| What | Where | Copy |
|------|-------|------|
| k3s server config: node addresses, the flannel interface, TLS SANs, the Okta OIDC flags of the API server (unused since Headlamp's removal, [TODO](TODO.md#cleanup)), the pods' DNS file | `/etc/rancher/k3s/config.yaml`. The unit's own flags are only k3s's default CIDRs and a SAN the file repeats | doc: written out in [the rebuild runbook](runbooks/rebuild-k3s-master.md#4-k3s-server) |
| Upstream DNS for pods | `/etc/k3s-resolv.conf`, named by `resolv-conf` in the k3s config. Every node has one | **Not recorded**: its contents |
| Cluster datastore and join token | `/var/lib/rancher/k3s/server/`: SQLite in `db/state.db` (a stale `etcd/` directory sits next to it), the token in `token` | none. Git recreates the objects, but a new server means a new token, and every worker has to re-join ([TODO](TODO.md#backups)) |
| Important data: Immich library, ActualBudget | `/srv/data/{immich,actualbudget}` | restic, local and B2 |
| local-path volumes: n8n, Kite | `/var/lib/rancher/k3s/storage/pvc-*` | restic. A new cluster gives them new names, see [the rebuild runbook](runbooks/rebuild-k3s-master.md#2-data-before-anything-writes-to-it) |
| NFS export of the Immich library to k3s-worker3 | `/etc/exports.d/immich.exports` | doc: [backup.md](backup.md#where-the-data-lives) |
| restic: env files, password file, four timers, SSH key and alias for worker1 | `/etc/restic/`, `restic-*.{service,timer}`, `/root/.ssh/` | password and B2 key in 1Password, the rest is described in [backup.md](backup.md) |
| Tailscale node and subnet router for `10.10.0.0/24`, address `100.96.117.64`. Key expiry is off and the route is approved | `tailscaled` | doc: [network-architecture.md](network-architecture.md#tailscale). The address is also hardcoded in Terraform (`internal_ingress_ip`) |
| Hermes agent and dashboard | user units `hermes-gateway.service` and `hermes-dashboard.service`, with the drop-in `proxy.conf`. Lingering is on for `yuandrk`, so they start without a login. Home `~/.hermes/`: `config.yaml`, `.env` (the agent's API keys and bot tokens), `auth.json`, `kube-sandbox.conf` and `sandbox/browserless.token` (both written by `make-kubeconfig.sh`), `sandbox/run-job.sh` | **none**: `config.yaml`, `.env` and `auth.json` have only `.bak-*` copies on the same disk and **are not in restic** ([TODO](TODO.md#backups)). `kube-sandbox.conf` and the token can be regenerated ([hermes-sandbox.md](hermes-sandbox.md#access)) |
| Admin kubeconfig copy | `~/.kube/config`, a copy of `k3s.yaml` (`system:masters`). k3s's `kubectl` uses it only when `KUBECONFIG` points at it ([access.md](access.md#login-surfaces)) | regenerated from the server |
| Samba | `smbd` and `nmbd`, listening on `10.10.0.1:139/445`: the wired LAN, and the tailnet through the subnet route | **Not recorded**: the shares in `/etc/samba/smb.conf`, and who uses them |
| Syncthing | user unit `syncthing.service`, listening on `*:22000`, web UI on `127.0.0.1:8384` | **Not recorded**: which folders it syncs, with which devices |
| Obsidian vault backup | user units `vault-backup.*`, key in `~/.restic-env` | goes to B2 bucket `obsidian-backup-yuandrk` |

## Every node

| What | Where | Copy |
|------|-------|------|
| SSH, keys only, on the [ports listed here](network-architecture.md#listening-ports). Root may log in with a key on k3s-master and k3s-worker1 (`PermitRootLogin without-password`), not on k3s-worker3 | sshd config | doc |
| `yuandrk` can sudo without a password | sudoers | doc |
| DNS: systemd-resolved with the global servers 1.1.1.1 and 1.0.0.1 and `Domains=~.`. Node names in `/etc/hosts` on k3s-master and k3s-worker3, not on k3s-worker1 | `/etc/systemd/resolved.conf.d/`, `/etc/hosts`, netplan | doc: written out in [the rebuild runbook](runbooks/rebuild-k3s-master.md#1-host) |
| Firewall: UFW is inactive on k3s-master and k3s-worker1. On k3s-worker3 it is active with one listed rule, `22/tcp`, and fail2ban runs there | `ufw` | doc. **Not recorded**: k3s-worker3's default UFW policy |
| Internet access: each node's own Wi-Fi, with an address from the BT router's DHCP. The wired LAN carries only cluster traffic, and nothing is NATed through k3s-master | netplan | doc: [network-architecture.md](network-architecture.md#segments) |
| k3s binary, with the previous one kept in `/root` after the last upgrade | `/usr/local/bin/k3s`. The workers keep the server URL and the join token in `/etc/systemd/system/k3s-agent.service.env` | doc: [runbooks/upgrade-k3s.md](runbooks/upgrade-k3s.md) |

## k3s-worker1

| What | Where | Copy |
|------|-------|------|
| k3s agent settings: node addresses, the flannel interface, the pods' DNS file | `/etc/rancher/k3s/config.yaml`. The unit has no flags of its own | doc |
| The disposable taint `homelab.yuandrk.net/disposable=true:NoSchedule` | `node-taint` in `/etc/rancher/k3s/config.yaml`, which applies when the node registers, plus `kubectl taint` on the live Node. Git only has the tolerations for it | doc. A re-registered node gets it back from the file |
| restic repository: user `restic`, SFTP-only key | `/srv/backup/restic`, `/srv/backup/.ssh/authorized_keys` | doc: [backup.md](backup.md#local-copy-k3s-worker1) |
| USB link power management off for the SSD's ASMedia bridge: `usbcore.quirks=174c:1156:k`. LPM is one unproven suspect in the [2026-10-05 hang](decisions.md#2026-10-10--important-data-on-k3s-master-in-three-copies) | `/boot/firmware/cmdline.txt`, the original kept as `cmdline.txt.bak-20261011` | doc |
| A hung disk reboots the node instead of leaving it up but unable to do I/O: `kernel.hung_task_panic = 1` panics after a task is blocked for 120 s, and the existing `kernel.panic = 10` reboots 10 s later | `/etc/sysctl.d/90-hung-task-panic.conf` | doc |
| Timezone Europe/London. The other nodes use UTC, so this node's timers and logs print BST | `timedatectl` | doc |

## k3s-worker3

| What | Where | Copy |
|------|-------|------|
| k3s agent settings: `--node-ip`, `--flannel-iface=enp3s0`, `--node-name` and the `nvidia.com/gpu=true` label are flags in the unit. Only `resolv-conf` is in `config.yaml` | `/etc/systemd/system/k3s-agent.service` | doc. The k3s install script would drop these flags, see [runbooks/upgrade-k3s.md](runbooks/upgrade-k3s.md) |
| PostgreSQL 16 (PGDG packages), cluster `16/main`, `listen_addresses = '*'`. Databases for Immich and n8n. Login roles `postgres`, `immich` (a superuser) and `n8n`. `pg_hba.conf` adds scram-sha-256 from `10.10.0.0/24` and `10.42.0.0/16` to Ubuntu's defaults | `:5432`, `/etc/postgresql/16/main/` | Immich's database: Immich's own dumps in the library (restic). n8n's: only the dumps taken by hand ([backup.md](backup.md#not-in-the-backup)) |
| local-path volumes: Fleet's MySQL, Prometheus, Loki, the Immich ML cache | `/var/lib/rancher/k3s/storage/` | **none**: restic runs on k3s-master only. Fleet's device inventory and its first-run settings (server URL, admin) live in that MySQL |
| Intel iGPU for Immich's hardware transcoding | `/dev/dri`. The render group GID `993` is hardcoded in the Immich HelmRelease | doc. Update `apps/immich` if a reinstall changes the GID |
| NVIDIA driver 535 / CUDA 12.2 for the MX130, with nvidia-container-toolkit | host packages | unused since the device plugin was removed in `db40da1`. Revert that commit to bring GPU scheduling back |
| Units `wol-enable.service` and `fix-tailscale-route.service` | `/etc/systemd/system/` | **Not recorded**: what they do. The first presumably enables Wake-on-LAN |

## External accounts

| Account | What lives there | Recreated from |
|---------|------------------|----------------|
| Cloudflare | zone `yuandrk.net`, tunnel `homeserver`, the proxied catch-all `*.yuandrk.net`, the API token CI uses | Terraform recreates the tunnel's ingress rules, the per-app CNAMEs and `*.home`. The tunnel itself and the catch-all record were made by hand |
| Okta (`okta.yuandrk.net`) | the apps for Kite and the Hermes dashboard (plus a bookmark tile, and `okta-mcp-browser` for an Okta MCP client), the groups `IT` and `Andriuk corp`, the app assignments, the sign-on policies | [access.md](access.md) describes each app. Nothing is exported |
| 1Password | vault `homelab`, the operator's service account | [secrets.md](secrets.md) |
| GitHub | Actions secrets, environment `homelab` (without protection rules), Flux's deploy key (read/write), the Renovate app, one webhook to n8n | [terraform-guide.md](terraform-guide.md#ci) |
| AWS | S3 state bucket, GitHub OIDC provider and role | Terraform stacks `aws-bootstrap` and `aws-oidc`, applied once from a laptop, not by CI. `aws-oidc` has no backend, so its state and its `terraform.tfvars` (the live trust patterns) exist only where it was applied. **Not recorded**: where that is |
| Backblaze B2 | buckets `homelab-backup-yuandrk` and `obsidian-backup-yuandrk`, bucket-scoped keys, the lifecycle rule, the account's storage cap | [backup.md](backup.md#offsite-copy-backblaze-b2) |
| Tailscale | the tailnet, approval of k3s-master's subnet route, the ACL | [network-architecture.md](network-architecture.md#tailscale). **Not recorded**: the ACL |
| BT router | DHCP for the Wi-Fi addresses `.223`, `.137` and `.246`. k3s-master's `node-external-ip`, the Hermes dashboard's EndpointSlice and Traefik's LAN address all assume `.223` | **Not recorded**: whether these are reservations, and whether a UPS protects any node |
