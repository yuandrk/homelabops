# Network

The physical network, how names resolve, and the three ways into the cluster. The exposure rule
in short is in [architecture.md](architecture.md#how-requests-get-in); the nodes' hardware and
roles are in [its node table](architecture.md#nodes).

## Segments

| Network | Range | Notes |
|---------|-------|-------|
| Wired LAN | `10.10.0.0/24` | Unmanaged gigabit switch. Cluster traffic, NFS, PostgreSQL |
| Home Wi-Fi | `192.168.1.0/24` | BT router, DHCP. Every node's internet access |
| Tailnet | `100.64.0.0/10` | Only k3s-master is a member. It routes the tailnet into the wired LAN |
| Pods | `10.42.0.0/16` | Flannel VXLAN, one `/24` per node |
| Services | `10.43.0.0/16` | ClusterIP. CoreDNS is `10.43.0.10` |

Every node has both links: cluster traffic on the wire, internet over its own Wi-Fi, which is
its default route. Nothing is NATed between the two.

```txt
             BT router, 192.168.1.0/24 ── internet
                  │ Wi-Fi          │ Wi-Fi          │ Wi-Fi
            [k3s-master]      [k3s-worker1]    [k3s-worker3]
                .223             .137             .246
                  │                │                │
 ═════════ wired LAN 10.10.0.0/24, unmanaged gigabit switch ═════════
                  │                │                │
            [k3s-master]      [k3s-worker1]    [k3s-worker3]
                .1               .2               .5
```

## Listening ports

| Node | Port | Service | Reachable from |
|------|------|---------|----------------|
| every node | 80, 443 | Traefik through k3s ServiceLB (svclb) | LAN, and tailnet through k3s-master |
| k3s-master, k3s-worker1 | 2222 | SSH, keys only | LAN |
| k3s-worker3 | 22 | SSH, keys only | LAN |
| every node | 9100 | node-exporter (host network) | LAN |
| k3s-master | 6443 | Kubernetes API | LAN, tailnet |
| k3s-master | 2049 | NFS, Immich library export to `10.10.0.5` only | wired LAN |
| k3s-master | 139, 445 | Samba, bound to `10.10.0.1` | wired LAN, tailnet |
| k3s-master | 22000 | Syncthing | LAN, tailnet |
| k3s-master | 9119 | Hermes dashboard, a host process | LAN, tailnet, and Traefik as `hermes.yuandrk.net` |
| k3s-worker1 | 2049 | NFS, a leftover export of the old Immich library ([TODO](TODO.md#cleanup)) | wired LAN |
| k3s-worker3 | 5432 | PostgreSQL, native. `pg_hba.conf` admits only the wired LAN and the pod network | LAN and pods |
| any node | 30283 | Immich NodePort, for the mobile app on the LAN | LAN |

Host firewalls are described in [off-git.md](off-git.md#every-node).

## Tailscale

k3s-master is a Tailscale node **and** the subnet router for `10.10.0.0/24`, at `100.96.117.64`,
with key expiry disabled. The workers are not on the tailnet. The subnet route is what makes the
wired addresses reachable from outside the house: from a laptop on the tailnet,
`ssh -p 22 10.10.0.5` reaches k3s-worker3 through k3s-master.

MagicDNS names (`<host>.<tailnet>.ts.net`) resolve **only** through `100.100.100.100`. They are
not in public DNS, so they cannot be a CNAME target in Cloudflare.

## DNS

There are three ways to reach a service, and the hostname says which one applies:

| Path | Hostname | Resolves to | Who can reach it |
|------|----------|-------------|------------------|
| Cloudflare tunnel | `<app>.yuandrk.net` | Cloudflare proxy IPs | The internet |
| Tailscale | `<app>.home.yuandrk.net` | `100.96.117.64` | Tailnet devices only |
| Direct | — | `192.168.1.223` / `10.10.0.1` | Home LAN |

### Split-horizon without a DNS server

The zone has a proxied catch-all `*.yuandrk.net`, created by hand and not in Terraform, so
**every** name in the zone resolves to Cloudflare unless a more specific record overrides it. A
name without a record of its own lands on that catch-all, whose origin does not answer:
Cloudflare returns 522 after about 20 seconds. The tunnel's terminal `http_status:404` only
answers a name that points at the tunnel without an ingress rule, which Terraform never creates.

Internal services are carved out by one DNS-only wildcard, `*.home.yuandrk.net A 100.96.117.64`
(`cloudflare_dns_record.internal_wildcard` in Terraform). `100.64.0.0/10` is CGNAT and
unroutable across the internet, so the name resolves everywhere but only a tailnet device can
connect. The closest wildcard wins (RFC 4592), so `*.home.yuandrk.net` beats `*.yuandrk.net` for
anything under `home.`.

**No DNS server is involved** ([why](decisions.md#2026-05-24--no-dns-server)): the split is made of
records, not of a service that can go down. It separates names and routing, not permissions.
Traefik listens on `0.0.0.0:80` on every node, so anything on the home Wi-Fi reaches an internal
app at `192.168.1.223` with the right `Host` header, and source-IP filtering cannot stop that
([why](decisions.md#2026-07-05--no-source-ip-allowlists)).

### Resolver chain

- **Nodes**: systemd-resolved with the global servers `1.1.1.1` and `1.0.0.1` (the files are in
  the [rebuild runbook](runbooks/rebuild-k3s-master.md#1-host)). The wired links also carry
  per-link servers from netplan: `10.10.0.1` with `1.1.1.1`, or with `8.8.8.8` and `8.8.4.4` on
  k3s-worker3. Nothing has answered DNS on `10.10.0.1` since Pi-hole was removed
  ([TODO](TODO.md#cleanup)).
- **Pods**: CoreDNS (`10.43.0.10`) answers `cluster.local` and the node names (NodeHosts), and
  forwards the rest to `/etc/k3s-resolv.conf` on the node, set by `resolv-conf` in the k3s
  config, because a pod cannot reach systemd-resolved's `127.0.0.53` stub. That file's contents
  are [not recorded](TODO.md#unknowns).

Pods are not on the tailnet, so a pod resolving `<app>.home.yuandrk.net` gets `100.96.117.64`
and cannot connect. If a pod ever needs an internal service by name, k3s's hook is a
`coredns-custom` ConfigMap in `kube-system`: the Corefile already imports
`/etc/coredns/custom/*.override` and `*.server`. Nothing needs it today.

## Cloudflare Tunnel

The tunnel `homeserver` was created by hand. Its routes are `local.tunnel_services` in
`terraform/live/homelab/cloudflare/main.tf`, every one to `traefik.kube-system.svc.cluster.local:80`
([terraform-guide.md](terraform-guide.md#the-cloudflare-stack)). The connector is the
`cloudflared` HelmRelease: two replicas in `networking`, with the token from 1Password.
