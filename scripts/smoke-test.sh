#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-opus-major}"
SERVICE="${SERVICE:-player-data-service}"
LOCAL_PORT="${LOCAL_PORT:-8080}"

echo "Port-forward svc/${SERVICE} (${NAMESPACE}) -> localhost:${LOCAL_PORT}"
kubectl -n "${NAMESPACE}" port-forward "svc/${SERVICE}" "${LOCAL_PORT}:80" >/tmp/port-forward.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT

# wait a bit
sleep 2

echo "GET /healthz"
curl -fsS "http://127.0.0.1:${LOCAL_PORT}/healthz" | grep -q "ok"

echo "GET /readyz"
curl -fsS "http://127.0.0.1:${LOCAL_PORT}/readyz" | grep -q "ready"

echo "GET /player-data"
curl -fsS "http://127.0.0.1:${LOCAL_PORT}/player-data" >/dev/null

echo "✅ smoke-test OK"