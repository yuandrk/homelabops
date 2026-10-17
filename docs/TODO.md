# Backlog

All open work and everything nobody has recorded yet, in one place. The other docs describe how
things are; where one of them mentions a gap, it links here. Delete an item in the commit that
closes it.

Last reviewed 2026-10-11, against the [inventory](runbooks/inventory.md) of the same day.

## Backups

- [ ] n8n is scaled to zero since 2026-10-17. Before scaling it back up, give its database a
      scheduled dump: it lives in the native PostgreSQL on k3s-worker3, which nothing backs up,
      and only dumps taken by hand exist, in `/srv/data/db-dumps/n8n/`, the last one after it
      stopped. Also move it to a stable release of 2.43 or later: 2.43.4 is a beta, and its
      migrations have already run
- [ ] Copy ActualBudget consistently: its SQLite files are read while the server runs, so a
      write during the backup can leave that night's copy inconsistent. Add a `sqlite3 .backup`
      pre-step. Until then, older snapshots and the clients' local copies cover it
- [ ] Back up the k3s server state: `server/db/` (SQLite, copied with `sqlite3 .backup` so the
      copy is consistent) and `server/token`. A rebuilt master could then restore the cluster
      instead of every worker re-joining a new one ([off-git.md](off-git.md#k3s-master))
- [ ] Back up Hermes' home `~/.hermes` (config, API keys, memory), which no copy covers
      ([off-git.md](off-git.md#k3s-master))

## Monitoring

- [ ] Grafana's `PostgreSQL-Homelab` datasource points at `k3s-worker1:5432`, where nothing
      listens: point it at k3s-worker3 or delete it
      (`infrastructure/monitoring/base/configs/datasources/postgres-datasource.yaml`)
- [ ] Watch the host processes (Tailscale, the NFS server, PostgreSQL, Hermes), which
      node-exporter sees only as machines: a blackbox probe or a systemd exporter. restic already
      reports to healthchecks.io ([backup.md](backup.md#monitoring))

## Reliability

- [ ] Pin the four infrastructure charts to exact versions, so major upgrades arrive as
      Renovate PRs instead of installing themselves, and pin cloudflared's image tag
      ([renovate-config.md](renovate-config.md#traps))
- [ ] Untangle the monitoring stack from the `infrastructure` Kustomization
      ([gitops.md](gitops.md#traps-in-this-repo))
- [ ] Decide whether Terraform applies need an approval: add a required reviewer to the
      `homelab` environment, or accept the merge as the only gate ([terraform-guide.md](terraform-guide.md#ci)).
      The apply step is still named "Apply (after env approval)"
- [ ] Decide what to do with the hand-made proxied catch-all `*.yuandrk.net`. Every name without
      a record of its own now ends in a Cloudflare 522
      ([network-architecture.md](network-architecture.md#split-horizon-without-a-dns-server))

## Resources

- [ ] k3s-worker3 memory overcommit: the Immich server limit is 8Gi, consider 6Gi
- [ ] Add limits to the pods that have none: traefik, immich-valkey

## Cleanup

- [ ] Remove the NFS provisioner (scaled to zero) together with the `storage` dependency of
      `apps`, and the old worker1 claims kept as a rollback path in `c36a446`. Then, on
      k3s-worker1: stop `nfs-server`, which still exports the old Immich library (98 GB in
      `/srv/nfs/immich`) read-write with `no_root_squash` to all of `10.10.0.0/24`; drop that
      export from `/etc/exports`; delete `/srv/nfs/immich` and the old ActualBudget volume
      `actualbudget-data` in `/var/lib/rancher/k3s/storage/`
- [ ] k3s-master: delete the inactive `k3s-agent.service`, which carries k3s-worker3's flags, and
      its `k3s-agent.service.env`, which holds a join token (both in `/etc/systemd/system/`)
- [ ] k3s-master keeps `/root/k3s-backup-pre-1.34`, a copy of the server state (join token
      included) from before the 2026-08-01 upgrade, and the workers keep the old binaries as
      `/root/k3s-v1.33.*.bin`. Delete them once a rollback to 1.33 is off the table
- [ ] k3s-worker3: remove `tailscaled` (installed, running, logged out), `sops`, `flux`, `gh`,
      and the kubeconfig in `~/.kube/` whose credentials the API server rejects
- [ ] Every node: drop the per-link DNS server `10.10.0.1` from the wired link in netplan.
      Nothing has answered DNS there since Pi-hole was removed
- [ ] SOPS leftovers: `.sops.yaml`, the `sops -d` permission and age-key read denies in
      `.claude/settings.json`, and `.claude/hooks/guard-secrets.sh`, which should flag committed
      plaintext `kind: Secret` instead
- [ ] Delete the vault items whose consumer is gone: `pgadmin-credentials`,
      `stirling-pdf-credentials`, `mcp-slack-bot-credentials`, `headlamp-oidc-authentik`,
      `headlamp-oidc-okta` and `headlamp-token`, and Headlamp's Okta app if one exists
- [ ] k3s-master: drop the four `oidc-*` entries of `kube-apiserver-arg` in
      `/etc/rancher/k3s/config.yaml` at the next k3s restart, an upgrade for instance. They
      served only Headlamp
- [ ] The Terraform workflows still watch `terraform/modules/**`, which no longer exists
- [ ] GitHub: delete the `CLAUDE_CODE_OAUTH_TOKEN` secret, unused since `9aa8bbb` removed the
      Claude workflows. The webhook to n8n points at `/webhook-test/…`, which answers only while
      the n8n editor is listening, and returned 404: move it to the production `/webhook/…` URL
      or delete it

## Unknowns

Nobody has written these down yet. The [inventory](runbooks/inventory.md) collects most of them,
and [off-git.md](off-git.md) marks where each belongs with **Not recorded**.

- What `/etc/k3s-resolv.conf` holds on each node (the pods' upstream DNS)
- The Samba shares on k3s-master and who uses them; the folders and devices Syncthing syncs there
- What `wol-enable.service` and `fix-tailscale-route.service` on k3s-worker3 do
- k3s-worker3's default UFW policy
- Whether the BT router reserves `.223`, `.137` and `.246` by DHCP, and whether a UPS protects
  any node
- The Tailscale ACL: who can reach `10.10.0.0/24`
- Where the `aws-oidc` Terraform state and its `terraform.tfvars` live
- Where the proxied catch-all `*.yuandrk.net` points
- What the 1Password items `k3s-sudo` and `legacy-key-yuandrk (from k3s-worker3)` hold, and
  whether `hermes-dashboard-oidc` is the Hermes dashboard's Okta client
- Why PostgreSQL on k3s-worker3 is a native install
- Which images run with the tag `latest` (cloudflared presumably does, see
  [renovate-config.md](renovate-config.md#traps))
