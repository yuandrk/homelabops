# Backlog

Open work that does not belong to a single doc. Gaps that do belong to one live in that doc,
next to their context:

- [backup.md](backup.md#still-missing): n8n database dump, backup alerting, the live SQLite copy
- [monitoring.md](monitoring.md#still-missing): alert delivery, rule labels, Loki retention
- [off-git.md](off-git.md): every **Not recorded** value, and the open questions

Last reviewed 2026-10-11.

## Reliability

- [ ] Pin the seven infrastructure charts to exact versions, so major upgrades arrive as
      Renovate PRs instead of installing themselves ([renovate-config.md](renovate-config.md#traps))
- [ ] Untangle the monitoring stack from the `infrastructure` Kustomization
      ([gitops.md](gitops.md#traps-in-this-repo))
- [ ] Check whether the Flux webhook works: `kubectl get receivers -A` ([off-git.md](off-git.md#open-questions))
- [ ] Rotate the Headlamp break-glass token ([access.md](access.md#the-headlamp-break-glass-token-has-probably-expired))
- [ ] Run the [inventory](runbooks/inventory.md) and reconcile the docs with it: the
      **Not recorded** cells in off-git.md and the **verify** steps of the rebuild runbook

## Resources

- [ ] k3s-worker3 memory overcommit: the Immich server limit is 8Gi, consider 6Gi
- [ ] Add limits to the pods that have none: traefik, immich-valkey, alloy

## Cleanup

- [ ] Remove the NFS provisioner (scaled to zero) together with the `storage` dependency of
      `apps`, and the old worker1 claims kept as a rollback path in `c36a446`
- [ ] SOPS leftovers: `.sops.yaml`, the `sops -d` permission and age-key read denies in
      `.claude/settings.json`, and `.claude/hooks/guard-secrets.sh`, which should flag committed
      plaintext `kind: Secret` instead
- [ ] The `headlamp-oidc` OnePasswordItem in `flux-system` (item `headlamp-oidc-authentik`) has
      no consumer
- [ ] The `flux-system` PodMonitor still selects the removed image-automation controllers
- [ ] The Terraform workflows still watch `terraform/modules/**`, which no longer exists
- [ ] Delete the `glance-credentials` item in 1Password
