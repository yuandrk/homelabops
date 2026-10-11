# Backlog

All open work and everything nobody has recorded yet, in one place. The other docs describe how
things are; where one of them mentions a gap, it links here. Delete an item in the commit that
closes it.

Last reviewed 2026-10-11, against the [inventory](runbooks/inventory.md) of the same day.

## First

- [ ] Raise the Backblaze B2 storage cap ([how](backup.md#offsite-copy-backblaze-b2)). The first
      offsite run stopped at about 10 GB with `storage cap exceeded` on 2026-10-11, and every
      upload to the account, the Obsidian vault's too, fails until it is raised. Then run
      `sudo systemctl start --no-block restic-b2-backup` on k3s-master (the first upload takes
      hours) and check the B2 `snapshots` ([backup.md](backup.md#day-to-day)).
- [ ] Check that Headlamp can still log in through Okta, or
      [recreate its app](access.md#recreating-headlamps-okta-app), and renew its expired
      [break-glass token](access.md#break-glass)

## Backups

- [ ] Give n8n's database a scheduled dump. It lives in the native PostgreSQL on k3s-worker3,
      which nothing backs up; only the dumps taken by hand before an upgrade exist, in
      `/srv/data/db-dumps/n8n/`
- [ ] Copy ActualBudget consistently: its SQLite files are read while the server runs, so a
      write during the backup can leave that night's copy inconsistent. Add a `sqlite3 .backup`
      pre-step. Until then, older snapshots and the clients' local copies cover it
- [ ] Back up the k3s server state: `server/db/` (SQLite, copied with `sqlite3 .backup` so the
      copy is consistent) and `server/token`. A rebuilt master could then restore the cluster
      instead of every worker re-joining a new one ([off-git.md](off-git.md#k3s-master))
- [ ] Back up Hermes' home `~/.hermes` (config, API keys, memory), which no copy covers
      ([off-git.md](off-git.md#k3s-master))
- [ ] Record how the first weekly `restic check` ended. It started at 07:00 UTC on 2026-10-11,
      and k3s-worker1, which it reads from, rebooted about 19 minutes later for a reason nobody
      has written down. Look at `journalctl -u restic-check` on k3s-master and
      `journalctl -b -1` on k3s-worker1

## Monitoring

- [ ] Alerting: the rules worth waking up for, and a way to deliver them (Alertmanager, or a
      Grafana contact point). A failed backup comes first: today it only shows up in `journalctl`
- [ ] Set a Loki retention. Nothing sets one and local-path does not cap the 10Gi volume, so
      logs pile up on k3s-worker3's root filesystem. If it fills, the kubelet starts evicting pods
      there, and the native PostgreSQL on that disk runs out of space as well
- [ ] Drop one of the two collectors of Flux object state: the stack's own kube-state-metrics or
      the separate `flux-kube-state-metrics` Deployment ([monitoring.md](monitoring.md#flux-metrics))

## Reliability

- [ ] Pin the seven infrastructure charts to exact versions, so major upgrades arrive as
      Renovate PRs instead of installing themselves, and pin cloudflared's image tag
      ([renovate-config.md](renovate-config.md#traps))
- [ ] Untangle the monitoring stack from the `infrastructure` Kustomization
      ([gitops.md](gitops.md#traps-in-this-repo))
- [ ] Decide whether Terraform applies need an approval: add a required reviewer to the
      `homelab` environment, or accept the merge as the only gate ([terraform-guide.md](terraform-guide.md#ci))
- [ ] Decide what to do with the hand-made proxied catch-all `*.yuandrk.net`. Every name without
      a record of its own now ends in a Cloudflare 522
      ([network-architecture.md](network-architecture.md#split-horizon-without-a-dns-server))

## Resources

- [ ] k3s-worker3 memory overcommit: the Immich server limit is 8Gi, consider 6Gi
- [ ] Add limits to the pods that have none: traefik, immich-valkey, alloy

## Cleanup

- [ ] Remove the NFS provisioner (scaled to zero) together with the `storage` dependency of
      `apps`, and the old worker1 claims kept as a rollback path in `c36a446`. Then, on
      k3s-worker1: stop `nfs-server`, which still exports the old Immich library (98 GB in
      `/srv/nfs/immich`) read-write with `no_root_squash` to all of `10.10.0.0/24`; drop that
      export from `/etc/exports`; delete `/srv/nfs/immich` and the old ActualBudget volume
      `actualbudget-data` in `/var/lib/rancher/k3s/storage/`
- [ ] k3s-master: delete the inactive `k3s-agent.service`, which carries k3s-worker3's flags, and
      its `k3s-agent.service.env`, which holds a join token (both in `/etc/systemd/system/`)
- [ ] k3s-worker3: remove `tailscaled` (installed, running, logged out), `sops`, `flux`, `gh`,
      and the kubeconfig in `~/.kube/` whose credentials the API server rejects
- [ ] Every node: drop the per-link DNS server `10.10.0.1` from the wired link in netplan.
      Nothing has answered DNS there since Pi-hole was removed
- [ ] SOPS leftovers: `.sops.yaml`, the `sops -d` permission and age-key read denies in
      `.claude/settings.json`, and `.claude/hooks/guard-secrets.sh`, which should flag committed
      plaintext `kind: Secret` instead
- [ ] Delete the `headlamp-oidc` OnePasswordItem in `flux-system`. It reads the vault item
      `headlamp-oidc-authentik`, a leftover of the Authentik era, and nothing consumes it
- [ ] Delete the vault items whose consumer is gone: `pgadmin-credentials`,
      `stirling-pdf-credentials`, `mcp-slack-bot-credentials`, and `headlamp-oidc-authentik`
      once the item above is gone
- [ ] The `flux-system` PodMonitor still selects the removed image-automation and
      image-reflector controllers
- [ ] The Terraform workflows still watch `terraform/modules/**`, which no longer exists
- [ ] GitHub: delete the `CLAUDE_CODE_OAUTH_TOKEN` secret, unused since the Claude workflows
      went in `9aa8bbb`. The webhook to n8n points at `/webhook-test/…`, which answers only while
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
- Which Okta app Headlamp logs in through, if any
- What the 1Password items `Backblaze B2 — restic repo`, `k3s-sudo` and
  `legacy-key-yuandrk (from k3s-worker3)` hold, and whether `hermes-dashboard-oidc` is the
  Hermes dashboard's Okta client
- Why PostgreSQL on k3s-worker3 is a native install
- Which images run with the tag `latest` (cloudflared presumably does, see
  [renovate-config.md](renovate-config.md#traps))
