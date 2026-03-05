#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." >/dev/null 2>&1 && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env}"
CREDENTIALS_DIR="$REPO_ROOT/.credentials"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"
TIMEOUT="${TIMEOUT_SECONDS}s"

log() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf '\nERROR: %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

b64dec() {
  if base64 --help 2>&1 | grep -q -- '--decode'; then
    base64 --decode
  else
    base64 -D
  fi
}

wait_for_ingress_admission() {
  local deadline now endpoints
  deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))

  while true; do
    endpoints="$(kubectl -n ingress-nginx get endpoints ingress-nginx-controller-admission -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
    if [[ -n "${endpoints// /}" ]]; then
      return 0
    fi

    now="$(date +%s)"
    if (( now >= deadline )); then
      return 1
    fi

    sleep 3
  done
}

wait_for_argocd_app() {
  local app="$1"
  local deadline now status sync health
  deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))

  while true; do
    status="$(kubectl -n argocd get application "$app" -o jsonpath='{.status.sync.status} {.status.health.status}' 2>/dev/null || true)"
    sync="${status%% *}"
    health="${status#* }"

    if [[ "$sync" == "Synced" && "$health" == "Healthy" ]]; then
      printf 'Application %s is Synced/Healthy.\n' "$app"
      return 0
    fi

    now="$(date +%s)"
    if (( now >= deadline )); then
      printf 'Timeout waiting for application %s (sync=%s, health=%s).\n' "$app" "$sync" "$health" >&2
      return 1
    fi

    printf 'Waiting for %s (sync=%s, health=%s)...\n' "$app" "${sync:-Unknown}" "${health:-Unknown}"
    sleep 5
  done
}

wait_for_argocd_app_healthy() {
  local app="$1"
  local deadline now status sync health
  deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))

  while true; do
    status="$(kubectl -n argocd get application "$app" -o jsonpath='{.status.sync.status} {.status.health.status}' 2>/dev/null || true)"
    sync="${status%% *}"
    health="${status#* }"

    if [[ "$health" == "Healthy" && "$sync" != "Unknown" ]]; then
      printf 'Application %s is Healthy (sync=%s).\n' "$app" "$sync"
      return 0
    fi

    now="$(date +%s)"
    if (( now >= deadline )); then
      printf 'Timeout waiting for application %s to be healthy (sync=%s, health=%s).\n' "$app" "$sync" "$health" >&2
      return 1
    fi

    printf 'Waiting for %s (sync=%s, health=%s)...\n' "$app" "${sync:-Unknown}" "${health:-Unknown}"
    sleep 5
  done
}

wait_for_argocd_app_exists() {
  local app="$1"
  local deadline now
  deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))

  while true; do
    if kubectl -n argocd get application "$app" >/dev/null 2>&1; then
      return 0
    fi

    now="$(date +%s)"
    if (( now >= deadline )); then
      printf 'Timeout waiting for application %s to be created.\n' "$app" >&2
      return 1
    fi

    printf 'Waiting for application %s to be created...\n' "$app"
    sleep 3
  done
}

debug_argocd_bootstrap() {
  printf '\n[debug] ArgoCD workloads status:\n' >&2
  kubectl -n argocd get deploy,statefulset,pods -o wide >&2 || true

  printf '\n[debug] Recent ArgoCD events:\n' >&2
  kubectl -n argocd get events --sort-by=.lastTimestamp >&2 | tail -n 40 || true

  printf '\n[debug] argocd-server logs (last 100 lines):\n' >&2
  kubectl -n argocd logs deploy/argocd-server --all-containers --tail=100 >&2 || true
}

wait_rollout_or_debug() {
  local resource="$1"
  if ! kubectl -n argocd rollout status "$resource" --timeout="$TIMEOUT"; then
    debug_argocd_bootstrap
    fail "ArgoCD bootstrap failed: rollout timeout on $resource"
  fi
}

get_secret_field_decoded() {
  local namespace="$1"
  local secret="$2"
  local key="$3"
  kubectl -n "$namespace" get secret "$secret" -o "jsonpath={.data.$key}" | b64dec
}

require_cmd kubectl
require_cmd base64

[[ -f "$ENV_FILE" ]] || fail "Missing env file: $ENV_FILE (copy .env.example to .env)"

log "Step 1: Preflight checks"
kubectl get nodes >/dev/null 2>&1 || fail "kubectl cannot reach cluster. Start minikube first."
kubectl -n ingress-nginx get deploy ingress-nginx-controller >/dev/null 2>&1 || fail "Ingress controller not found. Run: minikube addons enable ingress"
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout="$TIMEOUT" >/dev/null
wait_for_ingress_admission || fail "Ingress admission webhook not ready yet. Retry in a few seconds."

log "Step 2: Bootstrap ArgoCD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -k "$REPO_ROOT/infra/clusters/local/argocd/install"
wait_rollout_or_debug deploy/argocd-redis
wait_rollout_or_debug deploy/argocd-repo-server
wait_rollout_or_debug statefulset/argocd-application-controller
wait_rollout_or_debug deploy/argocd-server

log "Step 3: Prepare Grafana credentials"
MONITORING_NAMESPACE="$MONITORING_NAMESPACE" bash "$REPO_ROOT/infra/scripts/create-grafana-admin-secret.sh" "$ENV_FILE"

log "Step 4: Deploy ArgoCD applications"
kubectl apply -k "$REPO_ROOT/infra/clusters/local/argocd/applications"

kubectl -n argocd get applicationset player-data-service >/dev/null 2>&1 || fail "ApplicationSet argocd/player-data-service not found after apply."

expected_apps=(
  "monitoring-stack"
  "player-data-service-dev"
  "player-data-service-staging"
  "player-data-service-prod"
)

prereq_apps=(
  "argo-rollouts"
  "kyverno"
  "policy-guardrails"
)

for app in "${prereq_apps[@]}"; do
  wait_for_argocd_app_exists "$app"
  wait_for_argocd_app_healthy "$app"
done

# Player-data apps may fail first sync before Rollouts CRDs exist; trigger a hard refresh once prerequisites are up.
for app in player-data-service-dev player-data-service-staging player-data-service-prod; do
  wait_for_argocd_app_exists "$app"
  kubectl -n argocd annotate application "$app" argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
done

for app in "${expected_apps[@]}"; do
  wait_for_argocd_app_exists "$app"
  wait_for_argocd_app "$app"
done

log "Step 5: Collect credentials"
mkdir -p "$CREDENTIALS_DIR"

argocd_password="$(get_secret_field_decoded argocd argocd-initial-admin-secret password | tr -d '\n')"
grafana_user="$(get_secret_field_decoded "$MONITORING_NAMESPACE" grafana-admin-credentials admin-user | tr -d '\n')"
grafana_password="$(get_secret_field_decoded "$MONITORING_NAMESPACE" grafana-admin-credentials admin-password | tr -d '\n')"

cat > "$CREDENTIALS_DIR/argocd.env" <<EOF
ARGOCD_URL=http://argocd.127.0.0.1.nip.io
ARGOCD_USER=admin
ARGOCD_PASSWORD=$argocd_password
EOF

cat > "$CREDENTIALS_DIR/grafana.env" <<EOF
GRAFANA_URL=http://grafana.127.0.0.1.nip.io
GRAFANA_USER=$grafana_user
GRAFANA_PASSWORD=$grafana_password
EOF

chmod 600 "$CREDENTIALS_DIR/argocd.env" "$CREDENTIALS_DIR/grafana.env"

log "Bootstrap completed"
printf 'Credentials saved to:\n- %s/argocd.env\n- %s/grafana.env\n' "$CREDENTIALS_DIR" "$CREDENTIALS_DIR"
printf 'Keep "minikube tunnel" running in another terminal for local URLs.\n'
