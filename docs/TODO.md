# Backlog

Open work that does not belong to a single doc. Gaps that do belong to one live in that doc,
next to their context:

- [backup.md](backup.md#still-missing): the offsite copy that has not completed, n8n's database
  dump, backup alerting, the live SQLite copy
- [monitoring.md](monitoring.md#still-missing): alerting, Loki retention
- [off-git.md](off-git.md): every **Not recorded** value, and the open questions

Last reviewed 2026-10-11, against the [inventory](runbooks/inventory.md) of the same day.

## First

- [ ] Raise the Backblaze B2 storage cap and finish the first offsite upload
      ([backup.md](backup.md#still-missing))
- [ ] Check that Headlamp can still log in through Okta, and renew its expired break-glass
      token ([access.md](access.md#headlamps-okta-app-is-missing))

## Reliability

- [ ] Pin the seven infrastructure charts to exact versions, so major upgrades arrive as
      Renovate PRs instead of installing themselves, and pin cloudflared's image tag
      ([renovate-config.md](renovate-config.md#traps))
- [ ] Untangle the monitoring stack from the `infrastructure` Kustomization
      ([gitops.md](gitops.md#traps-in-this-repo))
- [ ] Back up the k3s server state: `server/db/` (SQLite, copied with `sqlite3 .backup` so the
      copy is consistent) and `server/token`. A rebuilt master could then restore the cluster
      instead of every worker re-joining a new one ([off-git.md](off-git.md#k3s-master))
- [ ] Back up Hermes' home `~/.hermes` (config, API keys, memory), which no copy covers
      ([off-git.md](off-git.md#k3s-master))
- [ ] Find out why k3s-worker1 rebooted at about 07:19 UTC on 2026-10-11, during the first
      weekly `restic check` ([backup.md](backup.md#still-missing))
- [ ] Decide whether Terraform applies need an approval: add a required reviewer to the
      `homelab` environment, or accept the merge as the only gate ([terraform-guide.md](terraform-guide.md#ci))

## Resources

- [ ] k3s-worker3 memory overcommit: the Immich server limit is 8Gi, consider 6Gi
- [ ] Add limits to the pods that have none: traefik, immich-valkey, alloy

## Cleanup

- [ ] Remove the NFS provisioner (scaled to zero) together with the `storage` dependency of
      `apps`, and the old worker1 claims kept as a rollback path in `c36a446`. Then, on
      k3s-worker1, stop `nfs-server`, drop its export and delete `/srv/nfs/immich`
      ([off-git.md](off-git.md#k3s-worker1))
- [ ] Host leftovers: the inactive `k3s-agent` unit and its token file on k3s-master;
      `tailscaled`, `sops` and a dead kubeconfig on k3s-worker3 ([off-git.md](off-git.md))
- [ ] SOPS leftovers: `.sops.yaml`, the `sops -d` permission and age-key read denies in
      `.claude/settings.json`, and `.claude/hooks/guard-secrets.sh`, which should flag committed
      plaintext `kind: Secret` instead
- [ ] The `headlamp-oidc` OnePasswordItem in `flux-system` (item `headlamp-oidc-authentik`) has
      no consumer
- [ ] Delete the 1Password items whose consumer is gone ([secrets.md](secrets.md#what-is-in-the-vault))
- [ ] The `flux-system` PodMonitor still selects the removed image-automation controllers
- [ ] The Terraform workflows still watch `terraform/modules/**`, which no longer exists
- [ ] GitHub: delete the unused `CLAUDE_CODE_OAUTH_TOKEN` secret. The webhook to n8n points at
      `/webhook-test/…`, which answers only while the n8n editor is listening, and returned 404:
      move it to the production `/webhook/…` URL or delete it
