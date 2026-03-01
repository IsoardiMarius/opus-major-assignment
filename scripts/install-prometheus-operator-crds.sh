#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-v0.89.0}"
BASE_URL="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/${VERSION}/example/prometheus-operator-crd"

CRDS=(
  alertmanagerconfigs
  alertmanagers
  podmonitors
  probes
  prometheusagents
  prometheuses
  prometheusrules
  scrapeconfigs
  servicemonitors
  thanosrulers
)

for crd in "${CRDS[@]}"; do
  kubectl apply --server-side -f "${BASE_URL}/monitoring.coreos.com_${crd}.yaml"
done

echo "Prometheus Operator CRDs installed (${VERSION})."
