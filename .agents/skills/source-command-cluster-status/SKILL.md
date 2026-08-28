---
name: "source-command-cluster-status"
description: "Read-only health snapshot of the Flux GitOps cluster"
---

# source-command-cluster-status

Use this skill when the user asks to run the migrated source command `cluster-status`.

## Command Template

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
