---
description: Reconcile the Flux GitRepository source then a Kustomization, and verify
argument-hint: "[apps|infrastructure|monitoring-configs|monitoring-controllers|storage|secrets]"
allowed-tools: Bash(flux reconcile:*), Bash(flux get:*), Bash(kubectl get:*)
---

Reconcile Flux following the deployment-workflow.md pattern.

Target Kustomization: **$1** (default to `apps` if no argument was given).

Steps:
1. Pull the latest commit into the cluster:
   ```bash
   flux reconcile source git flux-system -n flux-system
   ```
2. Reconcile the target Kustomization:
   ```bash
   flux reconcile kustomization $1 -n flux-system
   ```
3. Verify and report:
   ```bash
   flux get kustomization $1 -n flux-system
   ```
   Then check the relevant HelmReleases / pods for that Kustomization's namespace and
   report whether the rollout succeeded. Flag any CrashLoopBackOff / ImagePullBackOff /
   not-Ready condition with its message.

This assumes the change is already committed and pushed to `main`. If `git status`
shows uncommitted changes, warn me first.
