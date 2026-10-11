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
- Wired LAN address `10.10.0.1/24`. The node names go in `/etc/hosts`, and systemd-resolved
  gets an override (the file name under `resolved.conf.d/` is not recorded):

  ```
  # /etc/hosts
  10.10.0.1 k3s-master
  10.10.0.2 k3s-worker1
  10.10.0.5 k3s-worker3
  ```

  ```ini
  # /etc/systemd/resolved.conf.d/
  [Resolve]
  DNS=1.1.1.1 1.0.0.1
  FallbackDNS=
  Domains=~.
  ```

- Wi-Fi `192.168.1.223`, which comes from the router's DHCP. The k3s config below, the Hermes
  dashboard's EndpointSlice and Traefik's LAN address all assume it, so make sure the new
  machine gets the same address.

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

Write the config before k3s first starts:

```yaml
# /etc/rancher/k3s/config.yaml
node-ip: 10.10.0.1
node-external-ip: 192.168.1.223
flannel-iface: enp0s31f6        # the wired interface; new hardware may name it differently
tls-san:
  - 10.10.0.1
  - 192.168.1.223
  - 100.96.117.64
kube-apiserver-arg:
  - "oidc-issuer-url=https://okta.yuandrk.net"
  - "oidc-client-id=<the client ID Headlamp uses>"
  - "oidc-username-claim=preferred_username"
  - "oidc-groups-claim=groups"
resolv-conf: /etc/k3s-resolv.conf
```

- The username claim is not `email`, so the API server prefixes it with the issuer and `#`. That
  gives the RBAC subject `https://okta.yuandrk.net#me@yuandrk.net` in git. The client ID has to
  be the one in Headlamp's `headlamp-oidc-okta` item, see
  [access.md](../access.md#recreating-headlamps-okta-app).
- **verify** `/etc/k3s-resolv.conf`: its contents are not recorded. Pods resolve external names
  through it, so it must list real upstream servers, not systemd-resolved's `127.0.0.53` stub.
- Install the k3s version the workers run (`k3s --version` on a worker), without flags, since
  the old unit's flags were only k3s's defaults:
  `curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=<version> sh -s - server`.
- `/etc/rancher/k3s/k3s.yaml` is root-only. Copy it to `~/.kube/config` for `yuandrk` and set
  `KUBECONFIG` in the shell profile ([access.md](../access.md#login-surfaces)).
- A new server has a new join token (`/var/lib/rancher/k3s/server/token`). On each worker, put it
  into `K3S_TOKEN` in `/etc/systemd/system/k3s-agent.service.env`, keep
  `K3S_URL='https://10.10.0.1:6443'`, and restart `k3s-agent`.
- k3s-worker1 taints itself when it registers (`node-taint` in its own config file). Check with
  `kubectl get node k3s-worker1 -o jsonpath='{.spec.taints}'`.

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
- **Hermes.** Reinstall it. Its `config.yaml`, `.env` (API keys, bot tokens) and `auth.json`
  had no copy outside the old disk, so it is configured again from scratch. Regenerate
  `kube-sandbox.conf` with `infrastructure/hermes-sandbox/make-kubeconfig.sh`, recreate the
  `proxy.conf` drop-in from [hermes-dashboard.md](../hermes-dashboard.md), and run
  `loginctl enable-linger yuandrk` so that its user units start without a login.
- **Samba and Syncthing** ran here too. Their configuration is not recorded
  ([off-git.md](../off-git.md#k3s-master)).

## 8. Check

- `flux get all -A`: everything `Ready`.
- `https://photos.yuandrk.net` and `https://budget.yuandrk.net` load from outside, and
  `qbit.home.yuandrk.net` loads from a tailnet device.
- Immich shows the library, which means worker3 mounted the NFS export.
- The next morning, `journalctl -u restic-backup -u restic-b2-backup` shows both runs succeeded.
