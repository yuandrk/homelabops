#!/usr/bin/env bash
# restic-pre-backup: consistent copies of k3s-master's live state, written under
# /srv/data/host-state so both restic runs pick them up without a change to their paths.
#
#   actualbudget/  SQLite files of /srv/data/actualbudget, through SQLite's online backup
#   k3s-server/    the k3s datastore db/state.db (same way) and the join token
#   hermes/        ~/.hermes of yuandrk, minus code and caches, its SQLite files copied the same way
#
# Installed as /usr/local/bin/restic-pre-backup (root, 0755) and run as ExecStartPre= of
# restic-backup.service and restic-b2-backup.service. A failure fails that night's run, so
# healthchecks.io reports it. See docs/backup.md#consistent-copies.
set -euo pipefail
umask 077

OUT=/srv/data/host-state
ACTUAL=/srv/data/actualbudget
K3S_SERVER=/var/lib/rancher/k3s/server
HERMES_HOME=/home/yuandrk/.hermes

log() { printf 'restic-pre-backup: %s\n' "$*"; }

# tr drops NUL bytes, which bash would otherwise warn about for every binary file.
is_sqlite() { [ "$(head -c 15 "$1" 2>/dev/null | tr -d '\0')" = "SQLite format 3" ]; }

# snapshot SRC DST: copy a live SQLite database with the online backup API, check the copy,
# then move it into place. sqlite3 runs as the file's owner: if it has to create a -wal or -shm
# next to the database, the app that owns the database can still open it afterwards.
snapshot() {
  local src=$1 dst=$2 uid gid tmp
  uid=$(stat -c %u "$src") gid=$(stat -c %g "$src")
  tmp=$(mktemp -d /var/tmp/restic-pre-backup.XXXXXX)
  chown "$uid:$gid" "$tmp"
  if ! setpriv --reuid="$uid" --regid="$gid" --clear-groups \
      sqlite3 "$src" ".timeout 30000" ".backup '$tmp/db'"; then
    log "backup failed: $src"; rm -rf "$tmp"; return 1
  fi
  if [ "$(sqlite3 "$tmp/db" 'PRAGMA quick_check;')" != ok ]; then
    log "quick_check failed on the copy of $src"; rm -rf "$tmp"; return 1
  fi
  mkdir -p "$(dirname "$dst")"
  mv -f "$tmp/db" "$dst"
  rm -rf "$tmp"
}

# Each section builds into $OUT/.new-<name> and swaps it in only when complete, so a failed
# night leaves the previous good copy in place.
begin() { rm -rf "$OUT/.new-$1"; mkdir -p "$OUT/.new-$1"; }
publish() {
  rm -rf "$OUT/.old-$1"
  [ -e "$OUT/$1" ] && mv "$OUT/$1" "$OUT/.old-$1"
  mv "$OUT/.new-$1" "$OUT/$1"
  rm -rf "$OUT/.old-$1"
}

actualbudget() {
  local new=$OUT/.new-actualbudget f n=0
  begin actualbudget
  while IFS= read -r -d '' f; do
    is_sqlite "$f" || continue
    snapshot "$f" "$new/${f#"$ACTUAL"/}" || return 1
    n=$((n + 1))
  done < <(find "$ACTUAL" -type f \( -name '*.sqlite' -o -name '*.db' \) -print0)
  [ "$n" -gt 0 ] || { log "no SQLite files under $ACTUAL"; return 1; }
  publish actualbudget || return 1
  log "actualbudget: $n databases"
}

k3s_server() {
  local new=$OUT/.new-k3s-server
  begin k3s-server
  snapshot "$K3S_SERVER/db/state.db" "$new/db/state.db" || return 1
  install -m 0600 "$K3S_SERVER/token" "$new/token" || return 1
  publish k3s-server || return 1
  log "k3s-server: state.db and token"
}

hermes() {
  local new=$OUT/.new-hermes f n=0
  begin hermes
  # Left out: code, runtimes, tools and caches, which a reinstall brings back; logs; and Hermes'
  # own backups and state snapshots, which restic's history replaces. -wal/-shm/-journal belong
  # to the live databases, which are copied below instead. --link-dest hard-links files that did
  # not change since the last copy, so a night costs only what changed.
  rsync -a --link-dest="$OUT/hermes" \
    --exclude='/hermes-agent/' --exclude='/tools/' --exclude='/installs/' --exclude='/node/' \
    --exclude='/venvs/' --exclude='/bin/' --exclude='/cache/' --exclude='/logs/' \
    --exclude='/backups/' --exclude='/state-snapshots/' \
    --exclude='node_modules/' --exclude='.venv/' --exclude='venv/' --exclude='__pycache__/' \
    --exclude='*-wal' --exclude='*-shm' --exclude='*-journal' \
    "$HERMES_HOME/" "$new/" || return 1
  while IFS= read -r -d '' f; do
    is_sqlite "$HERMES_HOME/${f#"$new"/}" || continue
    snapshot "$HERMES_HOME/${f#"$new"/}" "$f" || return 1
    n=$((n + 1))
  done < <(find "$new" -type f -print0)
  publish hermes || return 1
  log "hermes: copied, $n databases"
}

command -v sqlite3 >/dev/null || { log "sqlite3 is not installed (apt install sqlite3)"; exit 1; }
install -d -m 0700 "$OUT"

failed=()
actualbudget || failed+=(actualbudget)
k3s_server || failed+=(k3s-server)
hermes || failed+=(hermes)

if [ "${#failed[@]}" -gt 0 ]; then
  log "failed: ${failed[*]}"
  exit 1
fi
