# Inventory: check the docs against the machines

The docs record intent and reasons. This runbook collects what is actually on the hosts and in the
cluster, so the two can be compared. It fills the **Not recorded** cells in
[off-git.md](../off-git.md) and the **verify** steps in
[rebuild-k3s-master.md](rebuild-k3s-master.md), and it catches drift: things changed by hand that
no doc mentions. Run it after a rebuild, after a batch of host changes, or whenever the docs feel
stale.

The collection is the read-only script [`inventory.sh`](inventory.sh) next to this page. Everything
under [The prompt](#the-prompt) is written for an agent that can reach the machines: Hermes on
k3s-master, or Claude Code on a laptop with SSH and `kubectl`. A person can follow it just as well.

## Handing it over

- **Hermes**: *"Read and follow docs/runbooks/inventory.md in yuandrk/homelabops. Read-only.
  Send me the report as a file."* Hermes runs on k3s-master as `yuandrk`, so it covers the
  master and the cluster well. It has to ask before it uses the admin kubeconfig.
- **Claude Code** on a laptop: *"Follow docs/runbooks/inventory.md."* It covers the hosts over
  SSH, and the cluster with `--cluster-only` and the laptop's kubeconfig. On macOS the script
  needs GNU sed (`brew install gnu-sed`) and stops before printing anything without it.
- **Yourself**: the same commands. If sudo ever asks for a password again, run `sudo -v` on each
  node first, so that `sudo -n` can use the cached credentials.

Running both is fine: Hermes sees the cluster best, Claude Code every host.

Bring the report back to the session that reconciles the docs. Do not commit it: the repository
is public, and the raw output is more detailed than the docs need to be.

## The prompt

You are collecting facts about a three-node k3s homelab, so that its documentation can be checked
against reality. Your job is **read-only collection**. Someone else will compare your report with
the docs and fix them. You do not edit docs, manifests or the machines.

### What you are looking at

Three nodes: `k3s-master` (`10.10.0.1`), `k3s-worker3` (`10.10.0.5`) and `k3s-worker1`
(`10.10.0.2`, a Raspberry Pi). Their roles are in [architecture.md](../architecture.md#nodes).
SSH listens on port 2222, **except on k3s-worker3, which uses 22**. The node names resolve through `/etc/hosts` on k3s-master and k3s-worker3. From a laptop, use
its own SSH config or the `10.10.0.x` addresses, which the tailnet reaches through k3s-master. The
cluster is k3s, managed by Flux from GitHub (`yuandrk/homelabops`, branch `main`).

Give extra care to the [Unknowns](../TODO.md#unknowns) in the backlog, and to any item there
that asks for a check on the machines.

### Rules

1. **Change nothing.** Do not run, on a node or against the cluster:
   - `kubectl apply/create/edit/patch/replace/delete/scale/annotate/label/rollout/exec`;
   - `flux reconcile/suspend/resume`;
   - `systemctl start/stop/restart/enable/disable/daemon-reload`;
   - `tailscale up/set`, `exportfs -r`, `ufw` changes;
   - package installs, or edits to any config file.

   The script's only request to a workload is a GET to Prometheus' rules API through the API
   server proxy.
2. **Run only the script and the commands on this page.** If you think something else is needed,
   ask Yurii first and say why.
3. **Root only through `sudo -n`**, which the script already uses. Never type, ask for or search
   for a password, and do not look for another way to get root. A `sudo: a password is required`
   line is an acceptable result.
4. **The cluster part needs cluster-wide read access**, which means the admin kubeconfig. Hermes
   normally uses the scoped `~/.hermes/kube-sandbox.conf`, which cannot see the cluster, so ask
   Yurii before using the admin one. Without it, run the script without `--cluster` and say so.
5. **No secret values in the report**: no passwords, tokens, private keys, client secrets, API
   keys or kubeconfig credentials. The script redacts what it recognises. Step 5 checks for what
   it missed. When in doubt, redact.
6. **Facts, not guesses.** Mark anything you inferred as *inferred*. Do not fix what you find:
   list it under Surprises.
7. **Not between 05:15 and 07:00 UTC.** The backups run then, and the script's `du` adds disk load.
8. **The report goes only to Yurii, as a file.** Never commit it, push it, upload it, or paste it
   anywhere public.

### Steps

1. **Get the script.** From a clone of the repository it is `docs/runbooks/inventory.sh`. Otherwise:

   ```bash
   curl -fsSL -o /tmp/inventory.sh \
     https://raw.githubusercontent.com/yuandrk/homelabops/refs/heads/main/docs/runbooks/inventory.sh
   ```

   If you were given this page on another branch, use that branch instead of `main`. **Read the
   script before running it.**

2. **k3s-master**, with the cluster part:

   ```bash
   bash /tmp/inventory.sh --cluster > /tmp/inventory-k3s-master.txt 2>&1
   ```

   From another machine:
   `ssh -o BatchMode=yes -p 2222 k3s-master 'bash -s -- --cluster' < inventory.sh > inventory-k3s-master.txt 2>&1`.
   `/etc/rancher/k3s/k3s.yaml` is root-only, and k3s's `kubectl` reads it whenever `KUBECONFIG`
   is unset, so the script points `KUBECONFIG` at `~/.kube/config` when that file exists. If the
   cluster part still fails, run the host part there and the cluster part from a machine with a
   working kubeconfig: `bash inventory.sh --cluster-only`.

3. **The workers**, host part only. Note the different SSH port on k3s-worker3:

   ```bash
   ssh -o BatchMode=yes -p 22   k3s-worker3 'bash -s' < /tmp/inventory.sh > /tmp/inventory-k3s-worker3.txt 2>&1
   ssh -o BatchMode=yes -p 2222 k3s-worker1 'bash -s' < /tmp/inventory.sh > /tmp/inventory-k3s-worker1.txt 2>&1
   ```

   If SSH fails (no key, host down), keep the error and carry on with the rest.

4. **Outside the hosts.** Answer what you can of [the questions below](#questions-outside-the-hosts)
   with tools you are already logged into, read-only (`op item list`, `gh api` GET requests,
   `tailscale status`, an Okta MCP server). Everything else goes under "Needs Yurii".

5. **Leak check.** This must print nothing:

   ```bash
   grep -nE 'eyJ[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE|K10[0-9a-f]{16}|ops_[A-Za-z0-9]{16}|tskey-|gh[pousr]_[A-Za-z0-9]{16}|sk-[A-Za-z0-9_-]{16}|AKIA[0-9A-Z]{16}' /tmp/inventory-*.txt
   ```

   If it prints anything, replace those values with `<redacted>` by hand, then run it again.

6. **Assemble the report** from the template below into
   `/tmp/inventory-report-<YYYY-MM-DD>.md` and send it to Yurii as a file. Then delete your
   `/tmp/inventory-*` files.

### Report template

````markdown
# Homelab inventory, <YYYY-MM-DD HH:MM> UTC

Collected by <agent> from <host>. Cluster part: <yes | no, because …>.

## Summary
- Hosts: k3s-master <done | failed: …>, k3s-worker3 <…>, k3s-worker1 <…>
- Left out or failed, and why: <e.g. "root-only reads on k3s-worker3: sudo needs a password">
- Surprises, at most 10: services, ports, files, cluster objects or results that look
  undocumented, broken or odd. Facts only, each with the section it comes from.

## Answers
One line per Unknown, and per check the backlog asks for: the answer and the section it comes
from, or "not collected" and why.

## Outside the hosts
O1 … O8: an answer, or "Needs Yurii".

## Raw output
### k3s-master
```text
<inventory-k3s-master.txt>
```
### k3s-worker3
```text
<inventory-k3s-worker3.txt>
```
### k3s-worker1
```text
<inventory-k3s-worker1.txt>
```
````

### Questions outside the hosts

- **O1 Okta.** For each app (Kite, Hermes Dashboard and any other): its type (Web, Native or
  SPA), client authentication, grant types, redirect URIs, and the users or groups assigned to
  it. Who is in `IT` and `Andriuk corp`. Which sign-on and app policies require MFA.
- **O2 Cloudflare.** DNS records in `yuandrk.net` that Terraform does not manage, the
  `*.yuandrk.net` catch-all among them. The status of the `homeserver` tunnel's connectors. Any
  Cloudflare Access applications. The permissions of the API token CI uses.
- **O3 GitHub** (`yuandrk/homelabops` settings). Webhooks: URL, events, and the result of the
  last delivery. The protection rules on the `homelab` environment. Branch protection on `main`.
  The names of the Actions secrets. Deploy keys, with title and read/write.
- **O4 Tailscale.** Whether k3s-master's subnet route is approved, and whether its key expiry is
  disabled. A summary of the ACL: who can reach `10.10.0.0/24`. Any other subnet routers or exit
  nodes.
- **O5 1Password.** The item titles in vault `homelab` (titles only:
  `op item list --vault homelab --format json | jq -r '.[].title'`). Which vaults the operator's
  service account can read. Where its token is kept.
- **O6 Backblaze B2.** Buckets, lifecycle rules, the application keys with their bucket scopes,
  and the account's caps (Caps & Alerts).
- **O7 AWS.** On which machine and path the `aws-oidc` Terraform state and `terraform.tfvars`
  live, and the live value of `github_repos_branches`.
- **O8 Home network.** Port forwards on the BT router (none are expected). DHCP reservations for
  `192.168.1.223`, `.137` and `.246`. Whether a UPS protects any node.
