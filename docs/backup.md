# Data placement and backups

Where the irreplaceable data lives, and how it gets a second copy every night.

## Why it is arranged this way

On 2026-10-05 the USB-SSD of `k3s-worker1` (Raspberry Pi 4, budget FIKWOT SSD behind an
ASMedia UAS bridge, root filesystem on the same disk) stopped completing I/O. The kernel stayed
up, nothing reached the journal, and photos and budget were down for five days. At that point
the Immich library existed in exactly one copy, on that disk.

Two rules came out of it:

1. **Important data lives on `k3s-master`** (Crucial P3 1 TB NVMe). `k3s-worker1` is a
   *disposable* node: tainted `homelab.yuandrk.net/disposable=true:NoSchedule`, it runs only
   DaemonSets and holds the backup repository, which is a second copy and never the only one.
2. **Nothing exists in one copy.** restic backs `k3s-master` up to `k3s-worker1` every night.

## Where the data lives

| Data | Location on k3s-master | How the pod reaches it |
|------|------------------------|------------------------|
| Immich library: originals, uploads, Immich's own nightly DB dumps (`backups/`), thumbs, encoded video | `/srv/data/immich` | NFS. `immich-server` stays on k3s-worker3 for the Intel iGPU. Static PV `immich-library-master` in [apps/immich/base/pv.yaml](../apps/immich/base/pv.yaml) |
| ActualBudget (SQLite) | `/srv/data/actualbudget` | hostPath, Deployment pinned to k3s-master |
| n8n, Kite, qBittorrent config | `/var/lib/rancher/k3s/storage/pvc-*` | local-path PVCs |

The NFS export is host config outside git:

```
# /etc/exports.d/immich.exports on k3s-master
/srv/data/immich 10.10.0.5(rw,sync,no_subtree_check,no_root_squash)
```

`sync` is deliberate, since originals land here and an acknowledged write must be on disk.
`no_root_squash` is needed because Immich writes as root. Only k3s-worker3 is allowed.

**Not in the backup:** `/srv/media` (re-downloadable media), the Postgres instance on k3s-worker3
(Immich's database is covered by Immich's own dumps in `library/backups`, but n8n's is not), and
cluster state (git is the source of truth).

## The backup

restic runs on the k3s-master **host** (systemd), not in k3s. A restore must not depend on the
cluster being healthy.

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

### Day-to-day

```bash
ssh k3s-master systemctl list-timers 'restic-*'
ssh k3s-master sudo journalctl -u restic-backup --since yesterday
ssh k3s-master "sudo bash -c 'set -a; . /etc/restic/restic.env; restic snapshots'"
ssh k3s-master sudo systemctl start restic-backup      # run one now
```

### Restore

```bash
# On k3s-master. Restore into a scratch dir first, then move into place.
sudo bash -c 'set -a; . /etc/restic/restic.env
  restic restore latest --target /tmp/restore --include /srv/data/actualbudget'
```

For a full Immich restore, scale `immich-server` to 0 first (`flux suspend helmrelease immich -n
apps` so Flux does not scale it back), restore `/srv/data/immich`, then resume.

If k3s-master itself is gone, any machine with restic, the password from 1Password and SSH access
to k3s-worker1 can read the repository.

## Still missing

- **Offsite copy.** Both copies are in the same house, so fire, theft or a power surge takes
  both. The plan is a second restic repository on S3 (`terraform/live/homelab`, eu-west-2) or B2,
  without `thumbs/` and `encoded-video/` (~19 GB that Immich can regenerate).
- **Alerting on a failed backup.** Alertmanager is disabled, so a failed run only shows up in
  `journalctl`.
- **n8n's database** (Postgres on k3s-worker3) has no dump.
- **ActualBudget is copied live.** Its SQLite files are read while the server runs, so a write
  during the backup could leave that night's copy inconsistent. Older snapshots and the clients'
  local copies cover this. A `sqlite3 .backup` pre-step would close the gap.
