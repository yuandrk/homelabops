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
  Send me the report as a file."* Hermes runs as `yuandrk` and cannot answer a `sudo` password
  prompt, so unless sudo is passwordless the root-only parts will say so. That is fine. The
  cluster part needs the admin kubeconfig, and Hermes has to ask before it uses it.
- **Claude Code** on a machine with SSH access to the nodes: *"Follow docs/runbooks/inventory.md."*
- **Yourself**, for full coverage: on each node run `sudo -v` first, then the script, so that
  `sudo -n` can use the cached credentials.

Bring the report back to the session that reconciles the docs. Do not commit it: the repository
is public, and the raw output is more detailed than the docs need to be.

## The prompt

You are collecting facts about a three-node k3s homelab, so that its documentation can be checked
against reality. Your job is **read-only collection**. Someone else will compare your report with
the docs and fix them. You do not edit docs, manifests or the machines.

### What you are looking at

| Node | Address | Role |
|------|---------|------|
| `k3s-master` | `10.10.0.1`, Wi-Fi `192.168.1.223`, Tailscale `100.96.117.64` | Control plane, important data under `/srv/data`, NFS server, restic backups, Tailscale subnet router, the Hermes agent |
| `k3s-worker3` | `10.10.0.5`, wired only | Immich, Fleet, Prometheus, native PostgreSQL |
| `k3s-worker1` | `10.10.0.2`, Wi-Fi `192.168.1.137` | Raspberry Pi, disposable, holds the local restic repository |

SSH listens on port 2222 on every node, and the node names resolve through `/etc/hosts` on the
nodes. The cluster is k3s, managed by Flux from GitHub (`yuandrk/homelabops`, branch `main`).

The docs currently cannot answer these questions, so give them extra care:

- the k3s server flags and `/etc/rancher/k3s/config.yaml` (including the Okta OIDC flags), where
  the workers keep their join token, and how the taint on k3s-worker1 is set;
- how k3s-worker3, which has no Wi-Fi, reaches the internet;
- PostgreSQL's roles and `pg_hba.conf`, and whether anything dumps its databases;
- whether Hermes' `config.yaml` is copied anywhere off the disk, and whether lingering is enabled
  for its user units;
- whether the restic backups are actually succeeding;
- in the cluster: whether a Flux `Receiver` exists, whether Prometheus loaded the
  `homelab-monitoring-rules` groups, when the Headlamp break-glass token expires, which chart
  versions are actually deployed, which node each PersistentVolume lives on, and which Flux
  Kustomization owns the monitoring objects.

### Rules

1. **Change nothing.** Do not run, on a node or against the cluster:
   - `kubectl apply/create/edit/patch/replace/delete/scale/annotate/label/rollout`;
   - `flux reconcile/suspend/resume`;
   - `systemctl start/stop/restart/enable/disable/daemon-reload`;
   - `tailscale up/set`, `exportfs -r`, `ufw` changes;
   - package installs, or edits to any config file.

   The only `kubectl exec` allowed is the read-only HTTP GET that the script itself makes.
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
   `ssh -o BatchMode=yes -p 2222 k3s-master 'bash -s -- --cluster' < inventory.sh > inventory-k3s-master.txt 2>&1`

3. **The workers**, host part only:

   ```bash
   for n in k3s-worker3 k3s-worker1; do
     ssh -o BatchMode=yes -p 2222 "$n" 'bash -s' < /tmp/inventory.sh > "/tmp/inventory-$n.txt" 2>&1
   done
   ```

   If SSH fails (no key, host down), keep the error and carry on with the rest.

4. **Outside the hosts.** Answer what you can of [the questions below](#questions-outside-the-hosts)
   with tools you are already logged into, read-only (`op item list`, `gh api` GET requests,
   `tailscale status`). Everything else goes under "Needs Yurii".

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

- **O1 Okta.** For each app (the k3s API used by Headlamp, Kite, Hermes Dashboard, and any
  other): its type (Web, Native or SPA), client authentication, grant types, redirect URIs, and
  the users or groups assigned to it. Who is in `homelab-admins`, `IT` and `Andriuk corp`. Whether
  sign-on requires MFA.
- **O2 Cloudflare.** DNS records in `yuandrk.net` that Terraform does not manage, the
  `*.yuandrk.net` catch-all among them. The status of the `homeserver` tunnel's connectors. Any
  Cloudflare Access applications. The permissions of the API token CI uses.
- **O3 GitHub** (`yuandrk/homelabops` settings). Webhooks: URL, events, and the result of the
  last delivery, especially for any hook pointing at `flux-webhook.yuandrk.net`. The protection
  rules on the `homelab` environment. Branch protection on `main`. The names of the Actions
  secrets. Deploy keys, with title and read/write.
- **O4 Tailscale.** Whether k3s-master's subnet route is approved, and whether its key expiry is
  disabled. A summary of the ACL: who can reach `10.10.0.0/24`. Any other subnet routers or exit
  nodes.
- **O5 1Password.** The item titles in vault `homelab` (titles only:
  `op item list --vault homelab --format json | jq -r '.[].title'`). Which vaults the operator's
  service account can read. Where its token is kept.
- **O6 Backblaze B2.** Buckets, lifecycle rules, and the application keys with their bucket scopes.
- **O7 AWS.** On which machine and path the `aws-oidc` Terraform state and `terraform.tfvars`
  live, and the live value of `github_repos_branches`.
- **O8 Home network.** Port forwards on the BT router (none are expected). DHCP reservations for
  `192.168.1.223` and `.137`. Whether a UPS protects any node.
