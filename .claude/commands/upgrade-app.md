---
description: Upgrade an app to a target version following the version-upgrade pattern
argument-hint: "<app> <version>"
---

Upgrade **$1** to version **$2** using the version-upgrade pattern from deployment-workflow.md.

1. Find the current deployed version:
   ```bash
   kubectl get deploy,helmrelease -n apps -l app=$1 2>/dev/null
   ```
   and locate the manifest that pins the version — either an image tag in
   `apps/$1/base/deployment.yaml` or chart/image values in a HelmRelease. Report the current
   version before changing anything.
2. Update the image tag (or, for Helm charts with component-specific images, set the tag
   per-component — not the top-level tag) to `$2` in the manifest. Show me the diff.
3. Stop here and confirm with me before committing. After approval: commit → push →
   `/reconcile apps`.
4. Monitor the rollout and report status — watch for CrashLoopBackOff / ImagePullBackOff /
   ContainerCreating, and confirm the running image tag matches `$2`:
   ```bash
   kubectl get pods -n apps -l app=$1
   kubectl get deploy -n apps -l app=$1 -o jsonpath='{.items[*].spec.template.spec.containers[*].image}'
   ```

Note: large images (500MB+) can take 5–10 min to pull on first deploy.
