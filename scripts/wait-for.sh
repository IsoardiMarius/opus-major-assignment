#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/wait-for.sh "kubectl -n argocd get deploy argocd-server" 120
CMD="${1:?command required}"
TIMEOUT="${2:-120}"

start="$(date +%s)"
while true; do
  if eval "$CMD" >/dev/null 2>&1; then
    exit 0
  fi
  now="$(date +%s)"
  if (( now - start > TIMEOUT )); then
    echo "Timed out after ${TIMEOUT}s waiting for: $CMD" >&2
    exit 1
  fi
  sleep 2
done