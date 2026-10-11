# Hermes Sandbox

A scoped workspace in the cluster for the Hermes agent, which runs on the k3s-master host
([why outside k3s](decisions.md#standing-decisions)): a place to install dependencies, run
throwaway code and keep a couple of small tool services without touching k3s-master itself.

## What this is and is not

**Is:** a guardrail against mistakes and mess. Nothing a Job does can write to the node, mount a
host path, reach the home LAN, exhaust the node's RAM, or outlive its TTL.

**Is not:** a security boundary against hostile code. There is no gVisor or Kata runtime, so
containers share the node kernel. It is fine for "a package of unknown quality", not for a
targeted exploit; that needs a separate VM.

Hermes also runs as `yuandrk`, whose `~/.kube/config` is a copy of the admin kubeconfig
(`system:masters`) and who can sudo without a password. The scoped kubeconfig below is the
*preferred* path, not a technical barrier. Making it one needs a separate uid and unit, which is
deliberately out of scope for now.

## Access

| | |
|---|---|
| Namespace | `hermes-sandbox` |
| ServiceAccount | `hermes-runner` |
| Kubeconfig | `~/.hermes/kube-sandbox.conf` on k3s-master (mode 0600). No copy is kept: regenerate it as below |

The account can create and delete pods, Jobs, ConfigMaps and Services in this namespace, read
logs and events, and `exec` into pods. It **cannot** read Secrets, create PVCs, or see anything
outside the namespace.

```bash
export KUBECONFIG=~/.hermes/kube-sandbox.conf
kubectl get pods            # namespace is baked into the context
```

`infrastructure/hermes-sandbox/make-kubeconfig.sh` generates the file. Run it on k3s-master with
the admin kubeconfig, because the sandbox account cannot read Secrets, its own token included.
The script then checks the scoping: `get pods -n apps`, `get secrets`, `get nodes` and
`get namespaces` must be denied, and `get pods/jobs/svc` in this namespace must work. To rotate
the credential, delete the `hermes-runner-token` Secret, let Flux recreate it, and re-run.

## Services

Both are ClusterIP-only, with no Ingress and no NodePort, so the LAN cannot reach them. Hermes
calls them by ClusterIP from the host, which works because k3s-master runs kube-proxy. The host
does not use cluster DNS, so resolve the address at call time; a Service recreated by Flux gets a
new ClusterIP:

```bash
SEARXNG=$(kubectl get svc searxng -o jsonpath='{.spec.clusterIP}')
curl -s "http://$SEARXNG:8080/search?q=kubernetes+networkpolicy&format=json" | jq '.results[0]'
```

### SearXNG — `searxng:8080`

Metasearch with no API key and no third party seeing every query. Three non-default settings in
`base/searxng-settings.yml` make it usable from code: `search.formats: [html, json]` (the JSON
API is off by default), `server.limiter: false` (the bot limiter rejects programmatic requests)
and `server.method: GET`. The `secret_key` comes from `SEARXNG_SECRET`, sourced from 1Password,
with no default, so a missing secret fails the pod at boot instead of running with the
well-known placeholder key. SearXNG reads its settings only at boot; the ConfigMap's hashed name
rolls the Deployment whenever the file changes.

### browserless / Chromium — `browserless:3000`

Headless Chromium behind a CDP endpoint, for pages a plain HTTP fetch cannot read, screenshots
and form filling. Every route requires the token. The sandbox account cannot read Secrets and the
host has no 1Password CLI, so `make-kubeconfig.sh` leaves the token in
`~/.hermes/sandbox/browserless.token`:

```bash
BROWSERLESS=$(kubectl get svc browserless -o jsonpath='{.spec.clusterIP}')
TOKEN=$(cat ~/.hermes/sandbox/browserless.token)
curl -s "http://$BROWSERLESS:3000/pressure?token=$TOKEN"
```

Connect Playwright or Puppeteer over `ws://$BROWSERLESS:3000?token=$TOKEN`. Chromium inside a
container runs without its own internal sandbox: the boundary is PodSecurity baseline, the
NetworkPolicy and the quota.

## Disposable Jobs

`infrastructure/hermes-sandbox/run-job.sh`, installed on k3s-master as
`~/.hermes/sandbox/run-job.sh`, ships a local script into a ConfigMap, runs it in a Job, streams
the logs and cleans up:

```bash
run-job.sh probe.py                                  # the image follows the extension: .py, .js, .sh
run-job.sh -d "requests beautifulsoup4" scrape.py    # installs the packages first
run-job.sh -i jbarlow83/ocrmypdf -t 600 ocr.sh       # another image, a longer deadline
```

`run-job.sh -h` lists the options, including the CPU and memory limits.

Every Job starts with a `wait-for-netpol` init container that blocks until the network policy is
actually in force. kube-router programs a pod's firewall chain only after it sees the pod, so a
short Job would otherwise run **unfiltered** for its first seconds; that was measured, not
guessed. The init container polls a destination the policy must block and lets the workload
start once that connection fails, giving up after 90 s rather than running unprotected. A
hand-written Job needs the same init container, or accepts that its first seconds are unfiltered.

Each Job also gets `backoffLimit: 0`, `activeDeadlineSeconds: 900`,
`ttlSecondsAfterFinished: 600`, `automountServiceAccountToken: false`, an `emptyDir` workspace,
and a `restricted` securityContext: non-root, `drop: [ALL]`, `RuntimeDefault` seccomp, read-only
root filesystem. The namespace only *enforces* `baseline`, so `restricted` is a default the
caller opts out of, rather than an admission wall that breaks `pip install` and every
root-by-default image. `audit` and `warn` at `restricted` still record each deviation.

Pick a public image per task with `-i` (`linuxserver/ffmpeg`, `jbarlow83/ocrmypdf`,
`pandoc/extra`): there is no registry to build a toolbox image into. Packages from `-d` go into
the workspace (`pip install --target /work/site`, `npm install --prefix /work`), because the root
filesystem is read-only and the job runs non-root. A job that truly needs system paths can drop
`runAsNonRoot` and `readOnlyRootFilesystem`: `baseline` still admits it, and `warn` reports it.

For an integration test (a throwaway Postgres, Redis or mock HTTP server), create a plain Pod and
a Service. Everything in the namespace can reach everything else in it, so a Job finds the
temporary database by Service name. Delete both when done: unlike a Job, a bare Pod has no TTL.

## Limits

The ResourceQuota and LimitRange in `base/` set the budget, and everything is pinned to
k3s-worker3, the only node with real headroom. **The real ceiling is about five concurrent
jobs**, and it comes from `limits`, not from the pod count: the two services hold 3 CPU / 4Gi of
limit and `run-job.sh` gives a job 1 CPU / 1Gi by default, so about five fit into the rest.

Past that, new pods are rejected at admission and the Job shows a `FailedCreate` event about
`exceeded quota: limits.cpu`, which `run-job.sh` reports instead of hanging. Finished pods do not
count. To clear Jobs by hand, use `kubectl delete job -l hermes.sandbox/role=job`: Jobs support
only `metadata.name` and `metadata.namespace` as field selectors.

## Network

Default-deny in both directions, then: DNS to CoreDNS; the internet, except `10.0.0.0/8`,
`172.16.0.0/12`, `192.168.0.0/16`, `100.64.0.0/10` and `169.254.0.0/16`; pods within the
namespace; and, from the host, only pods labelled `hermes.sandbox/role: service`. So PyPI, npm
and GitHub work, while the Kubernetes API, Traefik, the other apps, the PostgreSQL on worker3 and
the home LAN do not. `base/network-policy.yaml` holds the rules and the reasoning behind each
CIDR. kube-router enforces them. To see drops:

```bash
ssh k3s-worker3 'sudo iptables -L -n -v | grep -A15 KUBE-POD-FW'
```

## Troubleshooting

- **Service unreachable from the host.** Almost always the `allow-node-to-services` policy:
  host → ClusterIP traffic is DNAT'd, so the source the policy sees is a node address. Confirm
  what the pod actually sees, starting with the drop counters above, before changing the CIDRs.
- **Pod stuck in `CreateContainerConfigError`.** The `hermes-sandbox-credentials` Secret is
  missing. The `secrets` Kustomization syncs it after `infrastructure`, so a short gap on first
  deploy is expected. If it persists, check the `OnePasswordItem` and the operator logs in the
  `onepassword` namespace.
- **Pod rejected at admission.** `violates PodSecurity "baseline:…"` means
  privileged/hostPath/hostNetwork, `exceeded quota` means the namespace budget, and
  `must specify limits` means the LimitRange could not default something.

## Removing it

Drop `hermes-sandbox/base` from `infrastructure/kustomization.yaml` **and** delete
`clusters/prod/secrets/hermes-sandbox-credentials.yaml` in the same commit. The `OnePasswordItem`
targets a namespace that `infrastructure` owns, so removing only the namespace leaves the shared
`secrets` Kustomization applying into a namespace that no longer exists, which stops it
reconciling **every** app's 1Password sync, not just this one. The vault item outlives the
manifests and is deleted by hand.
