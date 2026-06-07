#!/usr/bin/env bash
# Warn-only PreToolUse guard (matcher: Bash) for secret hygiene.
#  - *.enc.yaml files must be SOPS-encrypted (contain ENC[ markers).
#  - age private keys (age.key, *.agekey) must never be committed.
# Behaviour: print a warning to stderr and exit 1 (non-blocking).
set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0

# Only inspect git add / git commit invocations.
printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+(add|commit)' || exit 0

warn=""

# age private keys referenced directly on the command line
if printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]])age\.key([^[:alnum:]]|$)|\.agekey([^[:alnum:]]|$)'; then
  warn+="⚠️  Secret warning: command references an age private key (age.key/*.agekey) — never commit these.\n"
fi

# Staged *.enc.yaml that are not actually encrypted
staged="$(git diff --cached --name-only 2>/dev/null || true)"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    *.enc.yaml)
      if [ -f "$f" ] && ! grep -q 'ENC\[' "$f" 2>/dev/null; then
        warn+="⚠️  Secret warning: staged '$f' looks DECRYPTED (no SOPS ENC[ markers). Run 'sops -e -i' before committing.\n"
      fi
      ;;
  esac
done <<< "$staged"

if [ -n "$warn" ]; then
  printf '%b' "$warn" >&2
  exit 1
fi

exit 0
