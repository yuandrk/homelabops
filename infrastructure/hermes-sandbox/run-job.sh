#!/usr/bin/env bash
# Run a local script inside the hermes-sandbox namespace as a disposable Job.
#
# Installed on k3s-master as ~/.hermes/sandbox/run-job.sh. Kept in the repo so it is versioned
# and reviewable; copy it to the host after changing it.
#
#   run-job.sh probe.py
#   run-job.sh -d "requests beautifulsoup4" scrape.py
#   run-job.sh -i node:22-slim -d "node-fetch" probe.js
#   run-job.sh -i jbarlow83/ocrmypdf -t 600 ocr.sh
#
# The script is shipped in a ConfigMap (1MiB ceiling), the Job runs it, logs are streamed back,
# and everything is removed afterwards. Nothing persists — see docs/hermes-sandbox.md.
set -euo pipefail

NS=hermes-sandbox
KUBECONFIG="${KUBECONFIG:-$HOME/.hermes/kube-sandbox.conf}"
export KUBECONFIG

IMAGE=""
DEPS=""
DEADLINE=900
CPU_LIMIT="1"
MEM_LIMIT="1Gi"

usage() {
    cat >&2 <<'EOF'
usage: run-job.sh [-i IMAGE] [-d "DEPS"] [-t SECONDS] [-c CPU] [-m MEM] SCRIPT

  -i  container image (default: inferred from the script extension)
  -d  space-separated packages to install before running (pip / npm)
  -t  activeDeadlineSeconds (default: 900)
  -c  CPU limit  (default: 1,   namespace max: 2)
  -m  memory limit (default: 1Gi, namespace max: 4Gi)

Supported extensions: .py (python:3.12-slim), .js (node:22-slim), .sh (alpine:3.21)
EOF
    exit 2
}

while getopts ":i:d:t:c:m:h" opt; do
    case "$opt" in
        i) IMAGE="$OPTARG" ;;
        d) DEPS="$OPTARG" ;;
        t) DEADLINE="$OPTARG" ;;
        c) CPU_LIMIT="$OPTARG" ;;
        m) MEM_LIMIT="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

SCRIPT="${1:-}"
[ -n "$SCRIPT" ] || usage
[ -f "$SCRIPT" ] || { echo "run-job.sh: no such file: $SCRIPT" >&2; exit 1; }

# DEPS is interpolated straight into the generated YAML and then into a shell command, so keep it
# to characters that appear in real package specs and nothing that could break out of either.
if [ -n "$DEPS" ] && ! printf '%s' "$DEPS" | grep -Eq '^[A-Za-z0-9@/._=<>~^ -]+$'; then
    echo "run-job.sh: -d accepts package names only (got: $DEPS)" >&2
    exit 1
fi

# 1MiB is the hard ConfigMap limit; stop well before it.
size=$(wc -c <"$SCRIPT")
if [ "$size" -gt 900000 ]; then
    echo "run-job.sh: $SCRIPT is ${size} bytes; the ConfigMap ceiling is 1MiB." >&2
    exit 1
fi

case "$SCRIPT" in
    *.py) ENTRY=main.py; DEFAULT_IMAGE=python:3.12-slim ;;
    *.js) ENTRY=main.js; DEFAULT_IMAGE=node:22-slim ;;
    *.sh) ENTRY=main.sh; DEFAULT_IMAGE=alpine:3.21 ;;
    *)    echo "run-job.sh: cannot infer a runtime from '$SCRIPT' (want .py/.js/.sh); pass -i" >&2; exit 1 ;;
esac
IMAGE="${IMAGE:-$DEFAULT_IMAGE}"

# Dependencies are resolved into the command here rather than passed as an env var: the Job YAML
# below is an unquoted heredoc, so anything shell-shaped left in the command string would be
# expanded by *this* shell instead of surviving into the container.
NL=$'\n'
RUN=""
case "$ENTRY" in
    main.py)
        [ -n "$DEPS" ] && RUN="pip install --quiet --no-cache-dir --target /work/site $DEPS$NL"
        RUN="${RUN}export PYTHONPATH=/work/site${NL}exec python /script/main.py"
        ;;
    main.js)
        RUN="export npm_config_cache=/work/.npm$NL"
        [ -n "$DEPS" ] && RUN="${RUN}npm install --silent --no-fund --no-audit --prefix /work $DEPS$NL"
        RUN="${RUN}export NODE_PATH=/work/node_modules${NL}exec node /script/main.js"
        ;;
    main.sh)
        RUN="exec sh /script/main.sh"
        ;;
esac

CM="hermes-script-$(date +%s)-$$"
JOB=""

cleanup() {
    kubectl -n "$NS" delete configmap "$CM" --ignore-not-found --wait=false >/dev/null 2>&1 || true
    [ -n "$JOB" ] && kubectl -n "$NS" delete job "$JOB" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

kubectl -n "$NS" create configmap "$CM" --from-file="$ENTRY=$SCRIPT" >/dev/null

# The restricted securityContext lives here, not on the namespace: enforcing it cluster-side
# would break `pip install` and every root-by-default image. Drop runAsNonRoot and
# readOnlyRootFilesystem for a specific job when you genuinely need system-wide installs —
# PodSecurity baseline still admits it, and the namespace's warn=restricted will say so.
#
# automountServiceAccountToken: false keeps the job from *accidentally* carrying cluster
# credentials. It is not a barrier against a job that wants them: anyone who can run this script
# can also write a Job spec that mounts a Secret from the namespace. See docs/hermes-sandbox.md.
JOB=$(kubectl -n "$NS" create -o jsonpath='{.metadata.name}' -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  generateName: hermes-job-
  namespace: $NS
  labels:
    hermes.sandbox/role: job
spec:
  backoffLimit: 0
  activeDeadlineSeconds: $DEADLINE
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        hermes.sandbox/role: job
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      nodeSelector:
        kubernetes.io/hostname: k3s-worker3
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        # Makes the emptyDir workspace group-writable for uid 1000. Without it a non-root job
        # cannot write to /work at all, and every dependency install fails.
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: task
          image: $IMAGE
          command: ["/bin/sh", "-c"]
          args:
            - |
              set -eu
$(printf '%s\n' "$RUN" | sed 's/^/              /')
          env:
            - name: HOME
              value: /work
          workingDir: /work
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: [ALL]
          volumeMounts:
            - name: work
              mountPath: /work
            - name: tmp
              mountPath: /tmp
            - name: script
              mountPath: /script
              readOnly: true
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: "$CPU_LIMIT"
              memory: $MEM_LIMIT
      volumes:
        - name: work
          emptyDir: {}
        - name: tmp
          emptyDir: {}
        - name: script
          configMap:
            name: $CM
EOF
)

echo "run-job.sh: $JOB ($IMAGE)" >&2

# Wait for a pod to leave Pending before following logs — `kubectl logs -f` errors out if no
# container has started. Admission failures (quota, PodSecurity) never produce a pod at all, so
# report the Job's events rather than spinning until the timeout.
pod=""
deadline=$((SECONDS + 120))
while [ "$SECONDS" -lt "$deadline" ]; do
    pod=$(kubectl -n "$NS" get pod -l "job-name=$JOB" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -n "$pod" ]; then
        phase=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)
        if [ "$phase" != "Pending" ] && [ -n "$phase" ]; then
            break
        fi
    fi
    sleep 2
done

if [ -z "$pod" ]; then
    echo "run-job.sh: no pod was created for $JOB — the spec was probably rejected:" >&2
    kubectl -n "$NS" describe job "$JOB" | sed -n '/Events:/,$p' >&2
    exit 1
fi

kubectl -n "$NS" logs -f "$pod" || true

# The Job status is the source of truth: `kubectl logs` exits 0 even when the run failed.
succeeded=""
failed=""
for _ in $(seq 1 30); do
    succeeded=$(kubectl -n "$NS" get job "$JOB" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)
    failed=$(kubectl -n "$NS" get job "$JOB" -o jsonpath='{.status.failed}' 2>/dev/null || true)
    if [ -n "$succeeded" ] || [ -n "$failed" ]; then
        break
    fi
    sleep 2
done

if [ "$succeeded" = "1" ]; then
    exit 0
fi

echo "run-job.sh: $JOB failed" >&2
exit 1
