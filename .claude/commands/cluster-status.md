---
description: Read-only health snapshot of the Flux GitOps cluster
allowed-tools: Bash(kubectl get:*), Bash(flux get:*), Bash(flux check:*), Bash(flux events:*)
---

Give me a concise health snapshot of the cluster. Run these read-only commands and
summarize the results (flag anything not Ready / not Running):

```bash
flux get kustomizations --all-namespaces
flux get helmreleases --all-namespaces
flux get sources git --all-namespaces
kubectl get pods --all-namespaces --field-selector=status.phase!=Running 2>/dev/null
kubectl get nodes -o wide
```

Then report:
- Any Kustomization/HelmRelease that is not `Ready=True` (with the message).
- Any pod not Running/Completed (with namespace + reason).
- Node readiness.
- A one-line overall verdict (healthy / needs attention).

Do not change anything — this is read-only.
