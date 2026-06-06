#!/usr/bin/env bash
# Warn-only PreToolUse guard (matcher: Bash).
# This repo is GitOps-managed. Local mutating cluster/infra commands bypass the
# commit -> push -> reconcile workflow and (for the cluster) self-heal away.
# Behaviour: print a warning to stderr and exit 1 (non-blocking) so the action
# still runs — the user/assistant decides whether to proceed.
set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0

# Allow harmless dry-runs / diffs.
case "$cmd" in
  *--dry-run*|*"kubectl diff"*) exit 0 ;;
esac

if printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]])terraform[[:space:]]+apply([^[:alnum:]]|$)'; then
  echo "⚠️  GitOps warning: 'terraform apply' run locally." >&2
  echo "    terraform.md: always use CI/CD for production changes, never apply locally to main." >&2
  echo "    Prefer a PR (terraform-plan.yml) then merge to main (terraform-apply.yml)." >&2
  exit 1
fi

if printf '%s' "$cmd" | grep -Eq 'kubectl[[:space:]]+(apply|delete|edit|patch|replace|scale)([^[:alnum:]]|$)'; then
  echo "⚠️  GitOps warning: direct 'kubectl' mutation." >&2
  echo "    This cluster is Flux-managed and self-heals — manual changes are reverted on the next reconcile." >&2
  echo "    Prefer editing manifests, then commit -> push -> flux reconcile (see deployment-workflow.md)." >&2
  exit 1
fi

exit 0
