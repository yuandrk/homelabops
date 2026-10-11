# Rebuild k3s-master

> **Draft, never rehearsed.** Assembled from the other docs, not from a real rebuild. Steps
> marked **verify** depend on values that are not recorded yet ([off-git.md](../off-git.md)).
> Collect them with the [inventory](inventory.md) before you need this page.

k3s-master is the single point of failure. It runs the control plane, holds every piece of
important data, exports the Immich library over NFS, routes the tailnet into the LAN and runs
Hermes. This is the order to bring it back on a new disk or new hardware.

## What you need

- 1Password, vault `homelab`: the restic password, the B2 key, and a token for the operator's
  service account (or the rights to issue a new one)
- A reachable backup: the restic repository on k3s-worker1, or B2 if worker1 is gone too
- GitHub access to `yuandrk/homelabops`, plus the Okta, Tailscale and Cloudflare admin consoles

## 1. Host

- Ubuntu 24.04, user `yuandrk`, SSH on port 2222 with keys only.
- The hostname must be `k3s-master`. Manifests pin pods with `kubernetes.io/hostname`.
- Wired LAN address `10.10.0.1/24`, Wi-Fi `192.168.1.223`, `/etc/hosts` entries and the
  systemd-resolved override from [network-architecture.md](../network-architecture.md#dns-configuration).

## 2. Data, before anything writes to it

1. Install restic and recreate `/etc/restic/restic.env`, `b2.env` and `password` as described
   in [backup.md](../backup.md), with the values from 1Password.
2. Restore into a scratch directory on the NVMe (not `/tmp`, the library is large):

   ```bash
   sudo bash -c 'set -a; . /etc/restic/restic.env
     restic restore latest --target /srv/restore \
       --include /srv/data --include /var/lib/rancher/k3s/storage'
   ```

   Take `restic.env` for the copy on worker1 or `b2.env` for the offsite copy. A restore from B2
   has no Immich thumbnails or encoded videos. Immich regenerates them, see [backup.md](../backup.md#restore).
3. Move `/srv/restore/srv/data` to `/srv/data`. That data is reached by fixed paths (hostPath,
   static NFS PV), so it reattaches by itself.
4. Leave the local-path volumes in `/srv/restore/var/lib/rancher/k3s/storage`. A new cluster
   creates its PVCs with new `pvc-<uid>` names, so the old directories would not be picked up.
   Their contents are copied into the new volumes in step 6.

## 3. NFS export

```bash
sudo apt install nfs-kernel-server
echo '/srv/data/immich 10.10.0.5(rw,sync,no_subtree_check,no_root_squash)' \
  | sudo tee /etc/exports.d/immich.exports
sudo exportfs -ra
```

## 4. k3s server

- Install the same k3s minor version the workers run (`k3s --version` on a worker).
- **verify** Server flags: `--cluster-cidr 10.42.0.0/16`, `--service-cidr 10.43.0.0/16` and a
  `--tls-san` whose value is not recorded.
- **verify** `/etc/rancher/k3s/config.yaml` with the Okta OIDC flags for the API server. The
  issuer is `https://okta.yuandrk.net`. The RBAC subject
  `https://okta.yuandrk.net#me@yuandrk.net` implies the default issuer prefix and the email
  claim as the username. The client ID comes from the Okta app.
- A new server has a new join token. On each worker, **verify** where the token lives, replace
  it, and restart `k3s-agent`.
- Re-taint the disposable node:
  `kubectl taint node k3s-worker1 homelab.yuandrk.net/disposable=true:NoSchedule`

## 5. Secrets and Flux

```bash
kubectl create namespace onepassword
kubectl -n onepassword create secret generic onepassword-token \
  --from-literal=token='<1Password service-account token>'

flux bootstrap github --owner=yuandrk --repository=homelabops \
  --branch=main --path=clusters/prod --personal
```

- Use the `flux` CLI version written in the header of
  `clusters/prod/flux-system/gotk-components.yaml`. A different version makes bootstrap commit
  an upgrade to `main`.
- Bootstrap creates a fresh deploy key. The Terraform stack `terraform/live/homelab/fluxcd` is
  the older way to do the same and still holds the previous key in its state.

## 6. Let Flux converge, then put the PVC data back

```bash
flux get kustomizations -A --watch
```

Order: `infrastructure` first, then `secrets` and `infrastructure-networking`; `storage`, then
`apps`; `monitoring-controllers`, then `monitoring-configs`. Pods may wait in
`CreateContainerConfigError` until the `secrets` Kustomization has run (see
[secrets.md](../secrets.md#adding-a-secret)).

For n8n, Kite and qBittorrent:

```bash
flux suspend kustomization apps          # otherwise Flux scales the app back up
kubectl -n apps scale deploy/<app> --replicas=0
kubectl get pv | grep <app>              # find the new pvc-<uid> directory
sudo rsync -a /srv/restore/var/lib/rancher/k3s/storage/<old-dir>/ /var/lib/rancher/k3s/storage/<new-dir>/
flux resume kustomization apps          # scales the app back up
```

## 7. Outside the cluster

- **Tailscale.** Install it, run `tailscale up --advertise-routes=10.10.0.0/24`, enable IP
  forwarding and approve the route in the admin console. If the address is no longer
  `100.96.117.64`, change `internal_ingress_ip` in `terraform/live/homelab/cloudflare/main.tf`.
- **restic.** Recreate the four timers from [backup.md](../backup.md) and run one backup by hand.
- **Hermes.** Reinstall it and restore `~/.hermes/config.yaml`, which has no copy outside the
  old disk. Restore `kube-sandbox.conf` from 1Password and the `proxy.conf` drop-in from
  [hermes-dashboard.md](../hermes-dashboard.md). **verify** that user units need
  `loginctl enable-linger yuandrk` to start without a login.

## 8. Check

- `flux get all -A`: everything `Ready`.
- `https://photos.yuandrk.net` and `https://budget.yuandrk.net` load from outside, and
  `qbit.home.yuandrk.net` loads from a tailnet device.
- Immich shows the library, which means worker3 mounted the NFS export.
- The next morning, `journalctl -u restic-backup -u restic-b2-backup` shows both runs succeeded.
