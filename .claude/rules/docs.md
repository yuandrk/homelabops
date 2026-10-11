# Keeping the Docs Honest

The docs in `docs/` hold what the repo and the cluster cannot say themselves: intent, reasons,
constraints, failure modes, and state outside git. Index: [docs/README.md](../../docs/README.md).

## Rules

- **Do not write down what `kubectl`, `flux` or `git` can answer.** Versions, counts, "currently
  runs on node X" and status checkmarks go stale within weeks. Write the invariant and its reason
  instead: "pinned to k3s-master because its data is a hostPath".
- **One fact, one place.** Link to the owner instead of copying. If you find the same fact in
  two docs, keep one and link the other.
- **Decisions go in [decisions.md](../../docs/decisions.md), not in agent memory.** Memory is local
  to one machine, so cloud sessions and humans never see it. Commit messages carry the
  evidence; decisions.md carries the reasoning.
- **Gaps go in the "Still missing" section** of the doc they belong to. Only cross-cutting work
  goes in [TODO.md](../../docs/TODO.md).
- Match the existing style: plain prose, tables for reference, no emoji headings, no "✅ status"
  blocks.
- **To check the docs against reality**, use [docs/runbooks/inventory.md](../../docs/runbooks/inventory.md).
  Its raw report stays out of git (the repository is public). Only the reconciled facts go into
  the docs.

## When you change X, update Y

| Change | Update |
|--------|--------|
| Add, remove or rename an app, or change its hostname | Services table in `README.md`, the table in [services.md](services.md), and `local.tunnel_services` if public |
| Remove an app | A line in the removal log in [decisions.md](../../docs/decisions.md#removed-apps), plus the checklist in [gitops.md](../../docs/gitops.md#removing-an-app) |
| Add or remove a secret | [secrets.md](../../docs/secrets.md#what-is-in-the-vault) item table |
| Change anything on a host (systemd unit, `/etc`, a package), or in an external console (Cloudflare, Okta, 1Password, Tailscale, B2, AWS) | [off-git.md](../../docs/off-git.md) |
| Change who can log in where, or a break-glass path | [access.md](../../docs/access.md) |
| Change where important data lives or how it is backed up | [backup.md](../../docs/backup.md) and the data section of [architecture.md](../../docs/architecture.md) |
| A choice a future reader would question | An entry in [decisions.md](../../docs/decisions.md) |
