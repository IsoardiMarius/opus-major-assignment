#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-help}"
DURATION_SECONDS="${2:-90}"
DEMO_NAMESPACE="${DEMO_NAMESPACE:-player-data-dev}"
DEMO_JOB_NAME="player-data-cpu-burner"

HOSTS=(
  "player-data-dev.127.0.0.1.nip.io"
  "player-data-staging.127.0.0.1.nip.io"
  "player-data-prod.127.0.0.1.nip.io"
)

usage() {
  cat <<USAGE
Usage:
  bash infra/scripts/demo-monitoring.sh traffic [duration_seconds]
  bash infra/scripts/demo-monitoring.sh cpu-burn [duration_seconds]
  bash infra/scripts/demo-monitoring.sh full-demo [duration_seconds]
  bash infra/scripts/demo-monitoring.sh clear-demo

Examples:
  bash infra/scripts/demo-monitoring.sh traffic 60
  bash infra/scripts/demo-monitoring.sh cpu-burn 120
  bash infra/scripts/demo-monitoring.sh full-demo 120
  bash infra/scripts/demo-monitoring.sh clear-demo
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_positive_int() {
  local value="$1"
  local name="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -le 0 ]]; then
    echo "$name must be a positive integer." >&2
    exit 1
  fi
}

check_prereqs() {
  kubectl get namespace "$DEMO_NAMESPACE" >/dev/null 2>&1 || {
    echo "Namespace not found: $DEMO_NAMESPACE" >&2
    echo "Run deployment first: bash infra/scripts/deploy.sh" >&2
    exit 1
  }

  kubectl -n "$DEMO_NAMESPACE" get prometheusrule player-data-service-demo-cpu >/dev/null 2>&1 || {
    echo "Missing PrometheusRule ${DEMO_NAMESPACE}/player-data-service-demo-cpu" >&2
    echo "Ensure ArgoCD sync is healthy for player-data-service-dev." >&2
    exit 1
  }
}

clear_demo() {
  kubectl -n "$DEMO_NAMESPACE" delete job "$DEMO_JOB_NAME" --ignore-not-found >/dev/null
  echo "Demo CPU burn job cleared (if it existed): ${DEMO_NAMESPACE}/${DEMO_JOB_NAME}"
}

start_cpu_burn() {
  local duration="$1"
  require_positive_int "$duration" "Duration"

  if (( duration < 60 )); then
    echo "Duration must be >= 60s to reliably satisfy alert 'for: 30s'." >&2
    exit 1
  fi

  clear_demo

  cat <<'EOF_JOB' | sed -e "s/__JOB_NAME__/${DEMO_JOB_NAME}/g" -e "s/__DURATION__/${duration}/g" | kubectl -n "$DEMO_NAMESPACE" apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: __JOB_NAME__
  labels:
    app.kubernetes.io/name: player-data-cpu-burner
    app.kubernetes.io/component: demo
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 120
  template:
    metadata:
      labels:
        app.kubernetes.io/name: player-data-cpu-burner
        app.kubernetes.io/component: demo
    spec:
      restartPolicy: Never
      containers:
        - name: burner
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              end=$(( $(date +%s) + __DURATION__ ))
              yes >/dev/null &
              yes >/dev/null &
              while [ "$(date +%s)" -lt "$end" ]; do sleep 1; done
          resources:
            requests:
              cpu: "100m"
              memory: "16Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
EOF_JOB

  echo "CPU burn job started for ${duration}s: ${DEMO_NAMESPACE}/${DEMO_JOB_NAME}"
  echo "Expected alert (after ~30-90s): PlayerDataServiceDevHighCpuDemo"
  echo "Alertmanager: http://alertmanager.127.0.0.1.nip.io"
}

generate_traffic() {
  local duration="$1"
  local end_ts now

  require_positive_int "$duration" "Duration"

  end_ts=$(( $(date +%s) + duration ))
  echo "Generating traffic for ${duration}s on: ${HOSTS[*]}"

  while true; do
    now=$(date +%s)
    if (( now >= end_ts )); then
      break
    fi

    for host in "${HOSTS[@]}"; do
      curl -fsS --max-time 2 "http://${host}/player-data" >/dev/null || true
      curl -sS -X POST --max-time 2 "http://${host}/player-data" >/dev/null || true
    done

    sleep 0.2
  done

  echo "Traffic generation completed."
  echo "Grafana: http://grafana.127.0.0.1.nip.io"
}

main() {
  require_cmd kubectl
  require_cmd curl

  case "$ACTION" in
    traffic)
      generate_traffic "$DURATION_SECONDS"
      ;;
    cpu-burn)
      check_prereqs
      start_cpu_burn "$DURATION_SECONDS"
      ;;
    full-demo)
      check_prereqs
      start_cpu_burn "$DURATION_SECONDS"
      generate_traffic "$DURATION_SECONDS"
      echo "Demo resources will self-clean after job completion (TTL=120s)."
      echo "You can clear immediately with: bash infra/scripts/demo-monitoring.sh clear-demo"
      ;;
    clear-demo)
      clear_demo
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      echo "Unknown action: $ACTION" >&2
      usage
      exit 1
      ;;
  esac
}

main
