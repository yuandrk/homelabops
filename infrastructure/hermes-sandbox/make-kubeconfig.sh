#!/usr/bin/env bash
# Build the scoped kubeconfig Hermes uses for the hermes-sandbox namespace.
#
# Run on k3s-master, as a user who can read the token Secret (i.e. with the admin kubeconfig —
# the sandbox account deliberately cannot read Secrets, including its own). Re-run it to rotate:
# delete the Secret, let Flux recreate it, then run this again.
#
#   sudo -E ./make-kubeconfig.sh
#
# The resulting file is a bearer token with create/delete rights on pods and Jobs in one
# namespace. It is not a cluster-admin credential, but it is still a credential: mode 0600, and
# it never goes into git.
set -euo pipefail

NS=hermes-sandbox
SA=hermes-runner
SECRET=hermes-runner-token
OUT="${OUT:-$HOME/.hermes/kube-sandbox.conf}"
SERVER="${SERVER:-https://127.0.0.1:6443}"

# Do not inherit KUBECONFIG pointing at the sandbox config itself on a re-run.
ADMIN_KUBECONFIG="${ADMIN_KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
[ -r "$ADMIN_KUBECONFIG" ] || ADMIN_KUBECONFIG="$HOME/.kube/config"
[ -r "$ADMIN_KUBECONFIG" ] || { echo "make-kubeconfig.sh: no readable admin kubeconfig" >&2; exit 1; }
export KUBECONFIG="$ADMIN_KUBECONFIG"

kubectl -n "$NS" get serviceaccount "$SA" >/dev/null

# The Secret is declared in git but populated by kube-controller-manager, so it can lag the
# apply by a few seconds on a fresh deploy.
token=""
for _ in $(seq 1 15); do
    token=$(kubectl -n "$NS" get secret "$SECRET" -o jsonpath='{.data.token}' 2>/dev/null || true)
    [ -n "$token" ] && break
    sleep 2
done
if [ -z "$token" ]; then
    echo "make-kubeconfig.sh: $SECRET has no token yet — is the Secret's" >&2
    echo "  kubernetes.io/service-account.name annotation pointing at $SA?" >&2
    exit 1
fi
token=$(printf '%s' "$token" | base64 -d)

ca=$(kubectl -n "$NS" get secret "$SECRET" -o jsonpath='{.data.ca\.crt}')

mkdir -p "$(dirname "$OUT")"
umask 077
cat >"$OUT" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: homelab
    cluster:
      server: $SERVER
      certificate-authority-data: $ca
users:
  - name: $SA
    user:
      token: $token
contexts:
  - name: $NS
    context:
      cluster: homelab
      user: $SA
      namespace: $NS
current-context: $NS
EOF
chmod 600 "$OUT"

echo "make-kubeconfig.sh: wrote $OUT" >&2
KUBECONFIG="$OUT" kubectl auth whoami >&2 || true

# Prove the scoping actually holds rather than assuming it.
echo "--- these must all be denied ---" >&2
for check in "get pods -n apps" "get secrets -n $NS" "get nodes" "get namespaces"; do
    # shellcheck disable=SC2086
    if KUBECONFIG="$OUT" kubectl $check >/dev/null 2>&1; then
        echo "  FAIL: 'kubectl $check' succeeded and should not have" >&2
    else
        echo "  ok (denied): kubectl $check" >&2
    fi
done
echo "--- these must all be allowed ---" >&2
for check in "get pods" "get jobs" "get svc"; do
    # shellcheck disable=SC2086
    if KUBECONFIG="$OUT" kubectl $check >/dev/null 2>&1; then
        echo "  ok (allowed): kubectl $check -n $NS" >&2
    else
        echo "  FAIL: 'kubectl $check -n $NS' was denied and should not have been" >&2
    fi
done
