# Data placement and backups

Where the irreplaceable data lives, and how it gets two more copies every night: one in the house
and one offsite in Backblaze B2.

## Why it is arranged this way

In October 2026 the USB-SSD of k3s-worker1 hung and took the only copy of the photo library
offline for five days ([decisions.md](decisions.md#2026-10-10--important-data-on-k3s-master-in-three-copies)).
Two rules came out of it:

1. **Important data lives on `k3s-master`'s NVMe.** `k3s-worker1` is a *disposable* node:
   tainted `homelab.yuandrk.net/disposable=true:NoSchedule`, it runs only DaemonSets and holds
   the backup repository, which is a second copy and never the only one.
2. **Nothing exists in one copy.** Every night restic backs `k3s-master` up twice: to
   `k3s-worker1` and to Backblaze B2.

| Copy | Where | What | Protects against |
|------|-------|------|------------------|
| 1 (live) | k3s-master NVMe, `/srv/data` | everything | — |
| 2 (local) | restic repo on k3s-worker1 | everything | master's disk dying, a bad delete (snapshots) |
| 3 (offsite) | restic repo in B2 bucket `homelab-backup-yuandrk` | everything except Immich `thumbs/` and `encoded-video/` | fire, theft, a power surge taking out the whole house |

## Where the data lives

| Data | Location on k3s-master | How the pod reaches it |
|------|------------------------|------------------------|
| Immich library: originals, uploads, Immich's own nightly DB dumps (`backups/`), thumbs, encoded video | `/srv/data/immich` | NFS. `immich-server` stays on k3s-worker3 for the Intel iGPU. Static PV `immich-library-master` in [apps/immich/base/pv.yaml](../apps/immich/base/pv.yaml) |
| ActualBudget (SQLite) | `/srv/data/actualbudget` | hostPath, Deployment pinned to k3s-master |
| n8n, Kite | `/var/lib/rancher/k3s/storage/pvc-*` | local-path PVCs |
| Database dumps taken by hand: before an upgrade that migrates a DB, or after an app is stopped (`pg_dump -Fc`, `mysqldump`) | `/srv/data/db-dumps/<app>/` (root, 0700) | Not mounted |

The NFS export is host config outside git:

```
# /etc/exports.d/immich.exports on k3s-master
/srv/data/immich 10.10.0.5(rw,sync,no_subtree_check,no_root_squash)
```

`sync` is deliberate, since originals land here and an acknowledged write must be on disk.
`no_root_squash` is needed because Immich writes as root. Only k3s-worker3 is allowed.

## Not in the backup

- The PostgreSQL on k3s-worker3. Immich's database is covered by Immich's own dumps in
  `library/backups`; n8n's only by the dumps taken by hand, in `/srv/data/db-dumps`. n8n is
  scaled to zero, so the last one, taken after it stopped, is complete.
- The local-path volumes on k3s-worker3: Fleet's MySQL, Prometheus, Loki.
- Hermes' home `~/.hermes` on k3s-master: its config, API keys and memory.
- Cluster state: git is the source of truth, apart from what [off-git.md](off-git.md) lists.

What to add is in [TODO](TODO.md#backups).

## The backup

restic runs on the k3s-master **host** (systemd), not in k3s, because a restore must not depend
on the cluster being healthy. Both repositories use the same password and the same chunker parameters,
so `restic copy` between them deduplicates if it is ever needed.

### Local copy (k3s-worker1)

| Piece | Where |
|-------|-------|
| Repository | `sftp:restic-worker1:/srv/backup/restic` (k3s-worker1's SSD) |
| Settings | `/etc/restic/restic.env` |
| Password | `/etc/restic/password` (0600). **A copy lives in 1Password, vault `homelab`, item `restic homelab`. Without it the repository is unreadable.** |
| Nightly | `restic-backup.timer`, 05:30 UTC: `backup /srv/data /var/lib/rancher/k3s/storage`, then `forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune` |
| Weekly check | `restic-check.timer`, Sunday 07:00 UTC: `check --read-data-subset=5%` |
| SSH to the repo | root's key `/root/.ssh/restic_worker1`, host alias `restic-worker1` in `/root/.ssh/config` (15 s keepalive, so a hung worker1 fails the run instead of hanging it) |

On k3s-worker1 the repository belongs to the system user `restic` (shell `nologin`, home
`/srv/backup`). Its key is pinned to SFTP in `/srv/backup/.ssh/authorized_keys` with
`restrict,command="internal-sftp"`, so sshd needs no config change and the key cannot open a
shell.

### Offsite copy (Backblaze B2)

| Piece | Where |
|-------|-------|
| Repository | `s3:https://s3.eu-central-003.backblazeb2.com/homelab-backup-yuandrk/restic`, through B2's S3 API, which restic recommends over its native B2 backend |
| Bucket | `homelab-backup-yuandrk`: private, lifecycle "keep only the last version" (with the S3 API a delete only hides a file, and this purges it after a day), no Object Lock |
| Credentials | `/etc/restic/b2.env` (root, 0600). The application key is limited to this one bucket. 1Password: vault `homelab`, item `Backblaze B2 — restic homelab` (fields `keyID (B2_ACCOUNT_ID)` and `applicationKey`) |
| Password | the same `/etc/restic/password` (1Password item `restic homelab`) |
| Nightly | `restic-b2-backup.timer`, 06:15 UTC, after the local run. Same paths, minus Immich `thumbs/` and `encoded-video/`, which Immich regenerates. `--limit-upload 5120` (5 MiB/s, well under k3s-master's Wi-Fi uplink, so the Cloudflare tunnel stays usable). Retention: `--keep-daily 7 --keep-weekly 4 --keep-monthly 12` |
| Monthly check | `restic-b2-check.timer`, first Sunday 08:00 UTC: `check --read-data-subset=2%` |

The key sits in a root-only file on purpose. The Obsidian vault's own B2 backup
(`~/.config/systemd/user/vault-backup.*`, bucket `obsidian-backup-yuandrk`) keeps its key in
`~/.restic-env`, which anything running as `yuandrk` can read, Hermes included. A separate key
for this bucket means that cannot delete the photo backups.

The B2 account must allow more than the free 10 GB: Backblaze → Caps & Alerts → a daily storage
cap above $0, which needs a payment method on the account. The cap is per account, so it covers
the Obsidian bucket too. If it ever falls back to the free tier, every upload to the account fails
with `storage cap exceeded`. A raised cap takes up to 10 minutes to apply.

### Day-to-day

```bash
ssh k3s-master systemctl list-timers 'restic-*'
ssh k3s-master sudo journalctl -u restic-backup -u restic-b2-backup --since yesterday
ssh k3s-master "sudo bash -c 'set -a; . /etc/restic/restic.env; restic snapshots'"   # local
ssh k3s-master "sudo bash -c 'set -a; . /etc/restic/b2.env; restic snapshots'"       # B2
ssh k3s-master sudo systemctl start restic-backup      # run the local one now
```

### Restore

```bash
# On k3s-master. Restore into a scratch dir first, then move into place.
sudo bash -c 'set -a; . /etc/restic/restic.env
  restic restore latest --target /tmp/restore --include /srv/data/actualbudget'
# restic keeps the full path: the files land in /tmp/restore/srv/data/actualbudget
```

Stop the app before moving data into place, and keep Flux from scaling it back up: for a plain
Deployment such as ActualBudget, `flux suspend kustomization apps` and scale it to 0; for Immich,
`flux suspend helmrelease immich -n apps` and scale `immich-server` to 0. Resume afterwards.

If k3s-master itself is gone, any machine with restic and the password from 1Password can read
the local repository. Its SFTP key lived on k3s-master, though, so reach `/srv/backup/restic`
through your own login to k3s-worker1 and sudo.

If the whole house is gone, any machine with restic and the two 1Password items can restore from
B2:

```bash
export AWS_ACCESS_KEY_ID=…  AWS_SECRET_ACCESS_KEY=…     # from "Backblaze B2 — restic homelab"
export RESTIC_REPOSITORY=s3:https://s3.eu-central-003.backblazeb2.com/homelab-backup-yuandrk/restic
restic snapshots                                         # asks for the "restic homelab" password
restic restore latest --target ./restore
```

A restore from B2 has no thumbnails or encoded videos. Immich rebuilds them once the library is
back: Administration → Jobs → Generate Thumbnails / Transcode Videos, "All".
