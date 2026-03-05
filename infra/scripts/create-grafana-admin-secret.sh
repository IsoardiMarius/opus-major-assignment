#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." >/dev/null 2>&1 && pwd)"
ENV_FILE="${1:-$REPO_ROOT/.env}"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE"
  echo "Create it from: $REPO_ROOT/.env.example"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${GRAFANA_ADMIN_USER:?GRAFANA_ADMIN_USER is required in $ENV_FILE}"
: "${GRAFANA_ADMIN_PASSWORD:?GRAFANA_ADMIN_PASSWORD is required in $ENV_FILE}"

kubectl create namespace "$MONITORING_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$MONITORING_NAMESPACE" create secret generic grafana-admin-credentials \
  --from-literal=admin-user="$GRAFANA_ADMIN_USER" \
  --from-literal=admin-password="$GRAFANA_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret ready: ${MONITORING_NAMESPACE}/grafana-admin-credentials"
