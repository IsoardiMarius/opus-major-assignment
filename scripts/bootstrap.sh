#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${REPO_ROOT}/bin"
ARGO_NS="argocd"
APP_YAML="${REPO_ROOT}/deploy/argocd/app-service.yaml"

MINIKUBE_BIN="${BIN_DIR}/minikube"
KUBECTL_BIN="${BIN_DIR}/kubectl"

log() { echo "==> $*"; }
warn() { echo "⚠️  $*" >&2; }
die() { echo "❌ $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

os_arch() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"   # linux / darwin
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) die "Unsupported architecture: $arch" ;;
  esac
  echo "${os} ${arch}"
}

ensure_minikube() {
  mkdir -p "${BIN_DIR}"
  if [ -x "${MINIKUBE_BIN}" ]; then
    return 0
  fi

  local os arch
  read -r os arch < <(os_arch)

  log "Downloading minikube locally to ${MINIKUBE_BIN} (${os}/${arch})"
  # minikube publishes a single binary per OS/arch on GCS
  local url="https://storage.googleapis.com/minikube/releases/latest/minikube-${os}-${arch}"
  curl -fsSL "${url}" -o "${MINIKUBE_BIN}"
  chmod +x "${MINIKUBE_BIN}"
}

ensure_kubectl() {
  mkdir -p "${BIN_DIR}"
  if [ -x "${KUBECTL_BIN}" ]; then
    return 0
  fi

  local os arch
  read -r os arch < <(os_arch)

  log "Downloading kubectl locally to ${KUBECTL_BIN} (${os}/${arch})"
  # Get stable kubectl version
  local version
  version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  local url="https://dl.k8s.io/release/${version}/bin/${os}/${arch}/kubectl"
  curl -fsSL "${url}" -o "${KUBECTL_BIN}"
  chmod +x "${KUBECTL_BIN}"
}

k() { "${KUBECTL_BIN}" "$@"; }
m() { "${MINIKUBE_BIN}" "$@"; }

wait_for_app() {
  local app_name="$1"
  local timeout_seconds="${2:-240}"
  local start now health sync

  log "Waiting for ArgoCD Application '${app_name}' to be Synced/Healthy (timeout ${timeout_seconds}s)"
  start="$(date +%s)"

  while true; do
    # When app is not created yet, jsonpath fails -> ignore
    health="$(k -n "${ARGO_NS}" get application "${app_name}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    sync="$(k -n "${ARGO_NS}" get application "${app_name}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"

    if [ "${health}" = "Healthy" ] && [ "${sync}" = "Synced" ]; then
      log "Application is Synced/Healthy ✅"
      return 0
    fi

    now="$(date +%s)"
    if (( now - start > timeout_seconds )); then
      warn "Timed out waiting for application."
      warn "Current status: health='${health:-<none>}' sync='${sync:-<none>}'"
      warn "Debug:"
      warn "  ${KUBECTL_BIN} -n ${ARGO_NS} get applications"
      warn "  ${KUBECTL_BIN} -n ${ARGO_NS} describe application ${app_name}"
      return 1
    fi

    sleep 3
  done
}

main() {
  log "Checks"
  need_cmd docker
  need_cmd curl

  # Download tools locally (no global install required)
  ensure_kubectl
  ensure_minikube

  # Quick sanity check: docker daemon accessible
  docker info >/dev/null 2>&1 || die "Docker daemon not reachable. Is Docker running?"

  log "Start minikube (driver=docker)"
  m start --driver=docker

  log "Install ArgoCD (official manifests)"
  k get ns "${ARGO_NS}" >/dev/null 2>&1 || k create ns "${ARGO_NS}"
  k apply -n "${ARGO_NS}" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  log "Wait for ArgoCD components"
  k -n "${ARGO_NS}" rollout status deploy/argocd-server --timeout=240s
  k -n "${ARGO_NS}" rollout status deploy/argocd-repo-server --timeout=240s
  k -n "${ARGO_NS}" rollout status deploy/argocd-application-controller --timeout=240s

  log "Apply ArgoCD Application"
  k apply -f "${APP_YAML}"

  # Derive app name from file (best effort) or hardcode if you prefer
  local app_name
  app_name="$(k -n "${ARGO_NS}" get applications -o jsonpath='{.items[?(@.metadata.name!="")].metadata.name}' | awk '{print $1}')"
  # If you know it, you can just set: app_name="player-data-service"
  app_name="${app_name:-player-data-service}"

  wait_for_app "${app_name}" 300

  log "Run smoke test"
  "${REPO_ROOT}/scripts/smoke-test.sh"

  echo
  echo "✅ All done!"
  echo
  echo "Access service (port-forward):"
  echo "  ${KUBECTL_BIN} -n opus-major port-forward svc/player-data-service 8080:80"
  echo
  echo "ArgoCD UI (optional):"
  echo "  ${KUBECTL_BIN} -n argocd port-forward svc/argocd-server 8081:443"
  echo "  then open: https://localhost:8081"
}

main "$@"