#!/usr/bin/env bash
# Read-only inventory of one homelab node, used to check docs/ against reality.
# Procedure, rules and report format: docs/runbooks/inventory.md
#
#   bash inventory.sh                  facts about this host
#   bash inventory.sh --cluster        the same, plus the cluster (needs kubectl with cluster-wide read)
#   bash inventory.sh --cluster-only   only the cluster, e.g. from a laptop with a kubeconfig
#
# Run it as your normal user, not as root. Root-only reads go through `sudo -n`:
# where sudo would ask for a password they print sudo's error instead, and the
# script carries on. Nothing here writes, restarts or reconfigures anything.
# All output passes through redact() before it is printed. Read it anyway
# before you share it.

set -uo pipefail
export LC_ALL=C
ME=${USER:-$(id -un)}

HOST=1 CLUSTER=0
case ${1:-} in
  --cluster) CLUSTER=1 ;;
  --cluster-only) HOST=0 CLUSTER=1 ;;
  "") ;;
  *) echo "usage: $0 [--cluster | --cluster-only]" >&2; exit 2 ;;
esac
MAXLINES=${MAXLINES:-400}

# redact() needs GNU sed. macOS ships BSD sed: use gsed (brew install gnu-sed) or stop here,
# before anything unredacted can be printed.
if ! sed --version >/dev/null 2>&1; then
  if command -v gsed >/dev/null 2>&1; then
    sed() { gsed "$@"; }
  else
    echo "inventory.sh needs GNU sed for its redaction (on macOS: brew install gnu-sed)" >&2
    exit 1
  fi
fi

# k3s's bundled kubectl prefers the root-only /etc/rancher/k3s/k3s.yaml whenever KUBECONFIG is
# unset, even if ~/.kube/config exists. Non-interactive SSH sessions do not read ~/.bashrc.
if [ "$CLUSTER" = 1 ] && [ -z "${KUBECONFIG:-}" ] && [ -r "$HOME/.kube/config" ]; then
  export KUBECONFIG="$HOME/.kube/config"
fi

section() { printf '\n===== %s =====\n' "$*"; }
run() {
  local label=$1
  shift
  printf '\n--- %s  [%s]\n' "$label" "$*"
  "$@" 2>&1 | head -n "$MAXLINES"
}
have() { command -v "$1" >/dev/null 2>&1; }
py() { python3 -c "$1"; }
S() { sudo -n "$@" 2>&1; }            # a root-only read; shows sudo's error if it would prompt
k() { kubectl --request-timeout=20s "$@"; }

redact() {
  # Key-based rules run first, so a value is redacted whole before the
  # pattern-based rules (JWTs, k3s tokens, API key prefixes) look at the rest.
  sed -E \
    -e '/-----BEGIN [A-Z ]*PRIVATE KEY-----/,/-----END [A-Z ]*PRIVATE KEY-----/c\<redacted private key>' \
    -e '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/c\<certificate>' \
    -e 's/(--[A-Za-z-]*(token|password|passwd|secret|api-?key)[A-Za-z-]*)([= ])[^[:space:]]+/\1\3<redacted>/Ig' \
    -e 's/(([A-Za-z0-9_.-]*(pass(word|wd)?|secret|token|api[_-]?key|access[_-]?key|private[_-]?key|credential|auth[_-]?key)[A-Za-z0-9_.-]*)["]?[[:space:]]*[:=][[:space:]]*)["]?[^[:space:]",}]+["]?/\1<redacted>/Ig' \
    -e 's#(://)[^/@[:space:]:]+:[^/@[:space:]]+@#\1<user>:<redacted>@#g' \
    -e 's/eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{4,}/<redacted jwt>/g' \
    -e 's/K10[0-9a-f]{16,}::[^[:space:]"]+/<redacted k3s token>/g' \
    -e 's/(sk-[A-Za-z0-9_-]{16,}|xox[abpr]-[A-Za-z0-9-]{10,}|gh[pousr]_[A-Za-z0-9]{20,}|tskey-[A-Za-z0-9-]{10,}|ops_[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16})/<redacted token>/g' \
    -e 's#(ssh-(rsa|ed25519|dss)|ecdsa-sha2-[a-z0-9-]+|sk-ssh-ed25519@openssh\.com) [A-Za-z0-9+/=]{20,}#\1 <key>#g'
}

# ---------------------------------------------------------------- host facts

h_tools() {
  local t
  for t in kubectl flux helm k3s restic tailscale op gh jq yq psql smartctl nvidia-smi docker; do
    printf '%-12s %s\n' "$t" "$(command -v "$t" || echo -)"
  done
}

h_identity() {
  date -u +%FT%TZ
  hostname
  uptime -p
  printf 'booted %s\n' "$(date -u -d "$(uptime -s)" +%FT%TZ)"
  timedatectl show -p Timezone 2>/dev/null
  grep PRETTY_NAME /etc/os-release
  uname -rm
  [ -r /proc/device-tree/model ] && { tr -d '\0' </proc/device-tree/model; echo; }
  lscpu | grep -E '^(Architecture|Model name|CPU\(s\)):'
  free -h | head -n 2
}

h_disks() {
  lsblk -d -e7 -o NAME,MODEL,SIZE,ROTA,TRAN
  echo
  df -hT -x tmpfs -x devtmpfs -x overlay -x squashfs -x efivarfs
}

h_gpu() {
  lspci 2>/dev/null | grep -iE 'vga|3d|display' || echo "no lspci, or no display devices"
  if have nvidia-smi; then
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
    nvidia-smi | grep -o 'CUDA Version: [0-9.]*'
  fi
  dpkg -l 2>/dev/null | awk '/^ii/ && /nvidia-(driver|container-toolkit|utils)/ {print $2, $3}'
  ls -l /dev/dri 2>/dev/null
  getent group render video
}

h_net() {
  ip -br addr
  echo
  ip route
  ip route get 1.1.1.1
  sysctl net.ipv4.ip_forward
  echo "## host NAT rules (Kubernetes chains left out)"
  S iptables -t nat -S POSTROUTING | grep -vE 'KUBE|CNI|FLANNEL|flannel'
  echo "## internet"
  curl -sS -o /dev/null -m 8 -w 'github.com: HTTP %{http_code}, local address %{local_ip}\n' https://github.com
}

h_dns() {
  local f
  for f in /etc/systemd/resolved.conf.d/*.conf; do
    [ -e "$f" ] && { echo "## $f"; grep -vE '^[[:space:]]*(#|$)' "$f"; }
  done
  resolvectl dns 2>/dev/null
  echo "## /etc/k3s-resolv.conf (the pods' upstream, named by resolv-conf in the k3s config)"
  grep -vE '^[[:space:]]*(#|$)' /etc/k3s-resolv.conf 2>&1
  echo "## /etc/hosts"
  grep -E 'k3s-|10\.10\.0\.' /etc/hosts
  echo "## public names, as this host resolves them"
  local n
  for n in "inventory-probe-$RANDOM.yuandrk.net" inventory-probe.home.yuandrk.net photos.yuandrk.net; do
    printf '%s -> %s\n' "$n" "$(getent ahostsv4 "$n" | awk 'NR==1 {print $1}')"
  done
}

h_tailscale() {
  have tailscale || { echo "tailscale not installed"; return; }
  tailscale version | head -n 1
  tailscale status --json 2>&1 | py '
import json, sys
raw = sys.stdin.read()
try:
    s = json.loads(raw).get("Self", {})
    for key in ("DNSName", "TailscaleIPs", "PrimaryRoutes", "KeyExpiry", "Online"):
        print(key + ":", s.get(key))
except Exception:
    print(raw[:300])'
  S tailscale debug prefs | py '
import json, sys
raw = sys.stdin.read()
try:
    p = json.loads(raw)
    for key in ("AdvertiseRoutes", "RouteAll", "CorpDNS", "ShieldsUp", "RunSSH", "AdvertiseTags"):
        print("prefs." + key + ":", p.get(key))
except Exception:
    print(raw[:300])'
}

h_access() {
  id
  local out
  out=$(S sshd -T)
  echo "$out" | grep -E '^(port|listenaddress|passwordauthentication|permitrootlogin|pubkeyauthentication|kbdinteractiveauthentication|allowusers) ' ||
    echo "$out" | head -n 2
  S ufw status verbose | head -n 15
  printf 'ufw unit: %s\n' "$(systemctl is-active ufw 2>&1)"
}

h_k3s() {
  have k3s && k3s --version | head -n 1
  local u f
  for u in k3s k3s-agent; do printf '%s: %s\n' "$u" "$(systemctl is-active "$u" 2>&1)"; done
  echo "## unit"
  systemctl cat k3s k3s-agent 2>/dev/null | grep -vE '^[[:space:]]*(#|$)'
  for f in /etc/rancher/k3s/config.yaml /etc/rancher/k3s/config.yaml.d/*.yaml \
    /etc/systemd/system/k3s.service.env /etc/systemd/system/k3s-agent.service.env; do
    [ -e "$f" ] || continue
    echo "## $f"
    S cat "$f"
  done
  echo "## datastore (state.db = SQLite, etcd/ = embedded etcd)"
  S ls -la /var/lib/rancher/k3s/server/db 2>/dev/null | head -n 10
  echo "## old binaries and backups from upgrades"
  S sh -c 'ls -d /root/k3s-* 2>/dev/null'
}

h_ports() {
  local out
  out=$(S ss -tlnpH)
  case $out in
    sudo:*) echo "$out" | head -n 1; ss -tlnH | awk '{print $4}' | sort -u ;;
    *) echo "$out" | awk '{print $4, $6}' | sort -u ;;
  esac
}

h_services() {
  echo "## running system services"
  systemctl list-units --type=service --state=running --no-legend --plain | awk '{print $1}'
  echo "## unit files under /etc/systemd/system"
  ls -1 /etc/systemd/system/*.service /etc/systemd/system/*.timer 2>/dev/null
  echo "## system timers"
  systemctl list-timers --all --no-legend 2>/dev/null
  echo "## user services ($ME)"
  systemctl --user list-units --type=service --all --no-legend --plain 2>&1 | awk '{print $1, $3, $4}'
  echo "## user timers"
  systemctl --user list-timers --all --no-legend 2>&1
  loginctl show-user "$ME" -p Linger 2>&1
  echo "## crontabs and /etc/cron.d"
  crontab -l 2>&1 | grep -vE '^[[:space:]]*(#|$)'
  S crontab -l | grep -vE '^[[:space:]]*(#|$)'
  ls -1 /etc/cron.d 2>/dev/null
  echo "## /usr/local/bin"
  ls -1 /usr/local/bin 2>/dev/null
  if have testparm; then
    echo "## Samba shares: name and path"
    testparm -s 2>/dev/null | grep -E '^\[|^[[:space:]]*(path|valid users|read only|guest ok) ='
  fi
}

h_storage() {
  local d
  for d in /srv/data /srv/media /srv/backup /srv/nfs; do
    [ -d "$d" ] || continue
    echo "## $d"
    S sh -c "timeout 300 du -sh $d/* 2>&1" | head -n 20
  done
  if [ -d /srv/data/db-dumps ]; then
    echo "## /srv/data/db-dumps, newest files"
    S sh -c 'find /srv/data/db-dumps -type f -printf "%TY-%Tm-%Td %TH:%TM %10s %p\n" | sort | tail -n 8'
  fi
  echo "## local-path volumes"
  S sh -c 'cd /var/lib/rancher/k3s/storage 2>/dev/null && timeout 300 du -sh -- * 2>/dev/null'
}

h_nfs() {
  grep -hvE '^[[:space:]]*(#|$)' /etc/exports /etc/exports.d/* 2>/dev/null
  S exportfs -v | head -n 10
  local u
  for u in nfs-server nfs-kernel-server; do printf '%s: %s\n' "$u" "$(systemctl is-active "$u" 2>&1)"; done
  echo "## NFS mounts on this host"
  findmnt -t nfs,nfs4 -o TARGET,SOURCE,OPTIONS 2>/dev/null
}

h_restic() {
  [ -d /etc/restic ] || { echo "no /etc/restic on this host"; return; }
  have restic && restic version
  S ls -l /etc/restic
  echo "## env files (variable names; only the repository is shown)"
  S sh -c 'for f in /etc/restic/*.env; do echo "# $f"; sed -E "/^[[:space:]]*(#|$)/d; /RESTIC_REPOSITORY=/!s/=.*/=<redacted>/" "$f"; done'
  echo "## units"
  systemctl cat 'restic-*.service' 'restic-*.timer' 2>/dev/null | grep -vE '^[[:space:]]*(#|$)'
  echo "## timers"
  systemctl list-timers 'restic-*' --all --no-legend
  echo "## outcome of each run, last 8 days"
  S journalctl -u 'restic-*' --since -8d --no-pager -o short-iso |
    grep -E 'snapshot [0-9a-f]+ saved|Fatal|no errors were found|Finished|Failed with result|Deactivated successfully' |
    tail -n 30
  echo "## newest snapshot in each repository (--no-lock --no-cache: nothing is written)"
  local f out
  for f in /etc/restic/restic.env /etc/restic/b2.env; do
    echo "# $f"
    out=$(S sh -c "set -a; . /etc/restic/restic.env; . $f; restic snapshots --no-lock --no-cache --latest 1 --compact")
    echo "${out:-(no snapshots)}" | tail -n 6
  done
}

h_postgres() {
  { have psql || [ -d /etc/postgresql ]; } || { echo "no PostgreSQL on this host"; return; }
  have pg_lsclusters && pg_lsclusters
  local q=(sudo -n -u postgres psql -XAt -c)
  "${q[@]}" "select version()" 2>&1
  "${q[@]}" "select name, setting from pg_settings where name in ('listen_addresses', 'port', 'data_directory')" 2>&1
  echo "## databases"
  "${q[@]}" "select datname, pg_size_pretty(pg_database_size(datname)) from pg_database where not datistemplate order by 1" 2>&1
  echo "## login roles"
  "${q[@]}" "select rolname, rolsuper from pg_roles where rolcanlogin order by 1" 2>&1
  echo "## pg_hba.conf, effective lines"
  S sh -c 'grep -hvE "^[[:space:]]*(#|$)" /etc/postgresql/*/main/pg_hba.conf'
}

h_user() {
  if [ -d "$HOME/.hermes" ]; then
    echo "## Hermes units"
    systemctl --user cat hermes-gateway.service hermes-dashboard.service 2>&1 | grep -vE '^[[:space:]]*(#|$)'
    local u
    for u in hermes-gateway hermes-dashboard; do printf '%s: %s\n' "$u" "$(systemctl --user is-active "$u" 2>&1)"; done
    echo "## ~/.hermes, names only"
    ls -la "$HOME/.hermes" | head -n 40
    echo "## config.yaml, top-level keys only"
    grep -oE '^[A-Za-z_][A-Za-z0-9_-]*:' "$HOME/.hermes/config.yaml" 2>/dev/null | sort -u
  else
    echo "no ~/.hermes for $ME"
  fi
  echo "## Obsidian vault backup"
  systemctl --user cat vault-backup.service vault-backup.timer 2>&1 | grep -vE '^[[:space:]]*(#|$)'
  [ -f "$HOME/.restic-env" ] && sed -E '/^[[:space:]]*(#|$)/d; /RESTIC_REPOSITORY=/!s/=.*/=<redacted>/' "$HOME/.restic-env"
  echo "## kubeconfigs for $ME (paths only)"
  find "$HOME/.kube" -maxdepth 1 -type f -printf '%M %u %p\n' 2>&1
  grep -sHE '^(export )?KUBECONFIG=' "$HOME/.bashrc" "$HOME/.profile" "$HOME/.hermes/.env"
  [ -r "$HOME/.kube/config" ] && KUBECONFIG="$HOME/.kube/config" kubectl config get-contexts 2>&1 | head -n 5
  local st
  for st in "$HOME/.local/state/syncthing/config.xml" "$HOME/.config/syncthing/config.xml"; do
    [ -r "$st" ] || continue
    echo "## Syncthing folders (label and path)"
    grep -oE '<folder [^>]*>' "$st" | grep -oE ' (label|path)="[^"]*"' | paste - -
    echo "## Syncthing devices (names only)"
    grep -oE '<device [^>]*name="[^"]*"' "$st" | grep -oE 'name="[^"]*"' | sort -u
  done
}

h_backup_target() {
  getent passwd restic || { echo "no restic user on this host"; return; }
  S du -sh /srv/backup/restic
  S sed -E 's#(ssh-[a-z0-9]+|ecdsa-[^ ]+) [A-Za-z0-9+/=]+#\1 <key>#' /srv/backup/.ssh/authorized_keys
  echo "## newest snapshot files"
  S sh -c 'find /srv/backup/restic/snapshots -type f -printf "%TY-%Tm-%Td %TH:%TM\n" | sort | tail -n 3'
}

h_disk_health() {
  local d
  if have smartctl; then
    for d in $(lsblk -dn -e7 -o NAME); do
      echo "## /dev/$d"
      S smartctl -H "/dev/$d" | tail -n 3
    done
  fi
  echo "## boots, last 5"
  S journalctl --list-boots --no-pager | tail -n 5
  echo "## kernel errors, last 14 days, every boot (journalctl -k would show only this boot)"
  S journalctl _TRANSPORT=kernel -p err --since -14d --no-pager | tail -n 20
}

# ------------------------------------------------------------- cluster facts

c_versions() {
  echo "kubeconfig: ${KUBECONFIG:-default}, context: $(kubectl config current-context 2>&1)"
  k version 2>&1 | grep -i server
  have flux && flux version 2>&1 | head -n 12
  k -n flux-system get deploy --no-headers \
    -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image
}

c_nodes() {
  k get nodes -o wide
  k get nodes -o json | py '
import json, sys
skip = ("kubernetes.io/", "node.kubernetes.io/", "beta.kubernetes.io/", "k3s.io/",
        "node-role.kubernetes.io/", "topology.kubernetes.io/", "feature.node.kubernetes.io/")
for n in json.load(sys.stdin)["items"]:
    m, st = n["metadata"], n["status"]
    labels = {k: v for k, v in m.get("labels", {}).items() if not k.startswith(skip)}
    cap = {k: st["capacity"].get(k) for k in ("cpu", "memory", "ephemeral-storage")}
    print(m["name"], "| taints:", n["spec"].get("taints"), "| extra labels:", labels, "| capacity:", cap)'
}

c_flux() {
  k get kustomizations.kustomize.toolkit.fluxcd.io -A
  echo "## HelmReleases: version asked for vs version deployed"
  k get helmreleases.helm.toolkit.fluxcd.io -A -o json | py '
import json, sys
for h in json.load(sys.stdin)["items"]:
    m, spec, status = h["metadata"], h["spec"], h.get("status", {})
    chart = spec.get("chart", {}).get("spec", {})
    wanted = chart.get("version") if chart else "chartRef " + str(spec.get("chartRef"))
    last = (status.get("history") or [{}])[0]
    ready = [c.get("status") for c in status.get("conditions", []) if c.get("type") == "Ready"]
    print(m["namespace"] + "/" + m["name"], "| chart:", chart.get("chart"), "| asked:", wanted,
          "| deployed:", last.get("chartVersion"), "| app:", last.get("appVersion"), "| ready:", ready)'
  echo "## Flux webhook receivers"
  k get receivers.notification.toolkit.fluxcd.io -A 2>&1
  k -n flux-system get svc webhook-receiver --no-headers 2>&1
}

c_monitoring() {
  echo "## which Flux Kustomization last applied each object (label kustomize.toolkit.fluxcd.io/name)"
  local o
  for o in helmrelease/kube-prometheus-stack helmrelease/loki helmrelease/alloy \
    podmonitor/flux-system deploy/flux-kube-state-metrics; do
    printf '%s: %s\n' "$o" "$(k -n monitoring get "$o" -o jsonpath='{.metadata.labels.kustomize\.toolkit\.fluxcd\.io/name}' 2>&1)"
  done
  echo "## Prometheus rule selector"
  k -n monitoring get prometheus -o jsonpath='{range .items[*]}{.metadata.name}{" ruleSelector="}{.spec.ruleSelector}{"\n"}{end}'
  echo "## rule groups Prometheus has loaded (GET through the API server proxy)"
  k get --raw /api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:9090/proxy/api/v1/rules 2>&1 | py '
import json, sys
raw = sys.stdin.read()
try:
    groups = json.loads(raw)["data"]["groups"]
    print(len(groups), "groups:", ", ".join(sorted(g["name"] for g in groups)))
except Exception:
    print(raw[:300])'
  echo "## Alertmanagers"
  k get alertmanagers.monitoring.coreos.com -A 2>&1
  echo "## Loki retention settings"
  k -n monitoring get cm loki -o jsonpath='{.data.config\.yaml}' 2>&1 |
    grep -nE 'retention|compactor|delete_request' || echo "nothing about retention in configmap loki"
}

c_storage() {
  echo "## PersistentVolumes: claim | class | size | node | path | phase"
  k get pv -o json | py '
import json, sys
for p in json.load(sys.stdin)["items"]:
    s = p["spec"]; claim = s.get("claimRef") or {}
    terms = s.get("nodeAffinity", {}).get("required", {}).get("nodeSelectorTerms") or []
    nodes = [v for t in terms for e in t.get("matchExpressions", []) for v in e.get("values", [])]
    nfs = s.get("nfs")
    path = (s.get("hostPath") or s.get("local") or {}).get("path") or (nfs and nfs["server"] + ":" + nfs["path"])
    print(p["metadata"]["name"], "|", claim.get("namespace", "-") + "/" + claim.get("name", "-"), "|",
          s.get("storageClassName"), "|", s.get("capacity", {}).get("storage"), "|", nodes, "|", path, "|",
          p["status"]["phase"])'
  echo "## PVCs that are not Bound"
  k get pvc -A --no-headers 2>&1 | awk '$3 != "Bound"'
  echo "## storage namespace"
  k -n storage get deploy 2>&1
}

c_secrets() {
  echo "## 1Password bootstrap token (existence and age only)"
  k -n onepassword get secret onepassword-token -o jsonpath='created {.metadata.creationTimestamp}{"\n"}' 2>&1
  k -n onepassword get deploy 2>&1
  echo "## OnePasswordItems"
  k get onepassworditems.onepassword.com -A -o json 2>&1 | py '
import json, sys
raw = sys.stdin.read()
try:
    for i in json.loads(raw)["items"]:
        conds = [(c.get("type"), c.get("status"), (c.get("message") or "")[:80]) for c in i.get("status", {}).get("conditions", [])]
        print(i["metadata"]["namespace"] + "/" + i["metadata"]["name"], "->", i["spec"].get("itemPath"), conds)
except Exception:
    print(raw[:300])'
  echo "## key names in each synced Secret (values are never printed)"
  local ns n
  k get onepassworditems.onepassword.com -A --no-headers \
    -o custom-columns=NS:.metadata.namespace,N:.metadata.name 2>/dev/null |
    while read -r ns n; do
      printf '%s/%s has keys %s\n' "$ns" "$n" "$(k -n "$ns" get secret "$n" -o jsonpath='{.data}' 2>&1 | py '
import json, sys
raw = sys.stdin.read()
print(" ".join(sorted(json.loads(raw))) if raw.startswith("{") else raw[:120])')"
    done
  echo "## Headlamp's OIDC client ID (an identifier, not a secret). The API server's oidc-client-id must match it"
  k -n kube-system get secret headlamp-oidc -o jsonpath='{.data.clientID}' 2>&1 | py '
import base64, sys
raw = sys.stdin.read().strip()
try:
    print("clientID", base64.b64decode(raw, validate=True).decode())
except Exception:
    print(raw[:200])'
  echo "## Headlamp break-glass token: expiry only, the token is not printed"
  k -n kube-system get secret headlamp-token -o jsonpath='{.data.token}' 2>&1 | py '
import base64, datetime, json, sys
raw = sys.stdin.read().strip()
try:
    part = base64.b64decode(raw).decode().split(".")[1]
    claims = json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4)))
    exp = claims.get("exp")
    print("sub:", claims.get("sub"), "| exp:",
          datetime.datetime.fromtimestamp(exp, datetime.timezone.utc).isoformat() if exp else "none")
except Exception as e:
    print("could not decode:", type(e).__name__)'
}

c_workloads() {
  echo "## namespaces"
  k get ns --no-headers -o custom-columns=N:.metadata.name | tr '\n' ' '
  echo
  echo "## ingress hosts"
  k get ingress -A --no-headers -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,HOSTS:.spec.rules[*].host
  echo "## NodePort and LoadBalancer services"
  k get svc -A --no-headers 2>/dev/null | awk '$3 == "NodePort" || $3 == "LoadBalancer"'
  echo "## workloads not applied by Flux, Helm or k3s itself"
  k get deploy,sts,ds,cronjob -A -o json | py '
import json, sys
for o in json.load(sys.stdin)["items"]:
    m = o["metadata"]; labels = m.get("labels") or {}; ann = m.get("annotations") or {}
    if ("kustomize.toolkit.fluxcd.io/name" in labels or "helm.toolkit.fluxcd.io/name" in labels
            or labels.get("app.kubernetes.io/managed-by") == "Helm"
            or any(k.startswith(("objectset.rio.cattle.io/", "svccontroller.k3s.cattle.io/"))
                   for k in list(labels) + list(ann))):
        continue
    print(o["kind"], m["namespace"] + "/" + m["name"], "| managed-by:", labels.get("app.kubernetes.io/managed-by"))'
  echo "## k3s add-on overrides"
  k -n kube-system get cm coredns-custom 2>&1 | tail -n 1
  k -n kube-system get helmchartconfigs.helm.cattle.io 2>&1
  echo "## images running with the tag latest, or with no tag"
  k get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' |
    sort -u | grep -E ':latest$|^[^:]+$' || echo "none"
  echo "## pods not Running or Completed"
  k get pods -A --no-headers 2>/dev/null | awk '$4 != "Running" && $4 != "Completed"'
  echo "## most restarted pods"
  k get pods -A --no-headers 2>/dev/null | sort -k5 -nr | head -n 8
}

# ---------------------------------------------------------------------- main

main() {
  if [ "$HOST" = 1 ]; then
    host_facts
  else
    section "cluster only, from $(hostname) as $ME, $(date -u +%FT%TZ)"
  fi
  if [ "$CLUSTER" = 1 ]; then
    section "cluster"
    run "versions" c_versions
    run "nodes" c_nodes
    run "Flux" c_flux
    run "monitoring" c_monitoring
    run "storage" c_storage
    run "secrets plumbing" c_secrets
    run "workloads and exposure" c_workloads
  fi
  section "end $(date -u +%FT%TZ)"
}

host_facts() {
  section "host $(hostname) as $ME, $(date -u +%FT%TZ)"
  run "tools on PATH" h_tools
  run "identity and hardware" h_identity
  run "disks and filesystems" h_disks
  run "GPU" h_gpu
  run "network" h_net
  run "DNS" h_dns
  run "Tailscale" h_tailscale
  run "access" h_access
  run "k3s" h_k3s
  run "listening TCP ports" h_ports
  run "services, timers, cron" h_services
  run "storage use" h_storage
  run "NFS" h_nfs
  run "restic (client side)" h_restic
  run "restic (repository side)" h_backup_target
  run "PostgreSQL" h_postgres
  run "user-level state ($ME)" h_user
  run "disk health and kernel errors" h_disk_health
}

main 2>&1 | redact
